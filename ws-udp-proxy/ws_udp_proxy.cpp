#include "ws_udp_proxy.h"
#include <arpa/inet.h>
#include <atomic>
#include <cstring>
#include <poll.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <time.h>
#include <unistd.h>
#include <QtCore/QDebug>

QT_USE_NAMESPACE

const WsUdpProxy::Config WsUdpProxy::defaultConfig = {
    .base_port = 5000,
    .base_bind_addr = "127.0.0.1",
    .remote_port = 6000,
    .remote_addr = "127.0.0.1",
    .ws_port = 0,
    .ws_url = "ws://localhost:8880",
    .ws_bind_addr = "127.0.0.1",
    .debug = false,
};

UdpThread::UdpThread(WsUdpProxy *skt, OsmoSocketFds fds)
    : wsThread_(skt)
    , fds_(fds)
    , loglevel_(0)
{
    connect(this, &UdpThread::WSWriteText, skt, &WsUdpProxy::WSWriteText);
    connect(this, &UdpThread::WSWriteData, skt, &WsUdpProxy::WSWriteData);
}

namespace {
std::atomic<uint64_t> lastind{0};

QString getTimestamp(uint64_t &out)
{
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    out = static_cast<uint64_t>(ts.tv_sec) * 1000000000 + ts.tv_nsec;

    return QString("%1:%2")
        .arg(static_cast<unsigned>(ts.tv_sec), 7)
        .arg(static_cast<unsigned>(ts.tv_nsec), 9);
}
} // namespace

void UdpThread::run()
{
    qDebug() << "UDP POLL THREAD STARTED!";

    constexpr int BUFFER_SIZE = 2048;
    char tmpbuff[BUFFER_SIZE];
    struct sockaddr_in from;
    socklen_t fromsz = sizeof(from);
    int rs;

    // Clean up socket queue
    for (const auto fd : fds_) {
        int rs;
        do {
            rs = recvfrom(
                fd, tmpbuff, sizeof(tmpbuff), MSG_DONTWAIT, (struct sockaddr *) &from, &fromsz);
        } while (rs > 0);
    }

    qDebug() << " -- POLL CYCLE -- ";
    uint64_t stm;

    while (!isInterruptionRequested()) {
        pollfd sockets[eOsmoSockets::SocketsCount] = {
            {fds_[eOsmoSockets::CLOCK], POLLIN, 0},
            {fds_[eOsmoSockets::CMD],   POLLIN, 0},
            {fds_[eOsmoSockets::DATA],  POLLIN, 0},
        };

        int res = poll(sockets, eOsmoSockets::SocketsCount, 1000);
        if (res < 0) {
            qWarning() << "Poll error:" << strerror(errno);
            return;
        } else if (res == 0) {
            continue;
        }

        for (int j = 0; j < eOsmoSockets::SocketsCount; j++) {
            if (sockets[j].revents & POLLIN) {
                rs = recvfrom(sockets[j].fd,
                    tmpbuff,
                    sizeof(tmpbuff),
                    MSG_DONTWAIT,
                    (struct sockaddr *) &from,
                    &fromsz);
                if (rs < 0) {
                    qWarning() << "recvfrom error:" << strerror(errno);
                    continue;
                }

                if (rs >= BUFFER_SIZE) {
                    qWarning() << "Buffer overflow detected, truncating message";
                    rs = BUFFER_SIZE - 1;
                }
                tmpbuff[rs] = 0;

                if (loglevel_)
                    qDebug() << "UDP[" << j << "] GOT" << rs << "bytes";

                if (j == eOsmoSockets::CLOCK
                    || j == eOsmoSockets::CMD) { //Text data: 0 - CLOCK / 1 - CMD
                    const QString timestamp = getTimestamp(stm);
                    qDebug() << timestamp << "<=" << tmpbuff;
                    emit WSWriteText(QString::fromLatin1(tmpbuff, rs));
                } else if (j == eOsmoSockets::DATA) { // 2 - Binary data
                    emit WSWriteData(QByteArray(tmpbuff, rs));
                }
            }
        }
    }
}

void WsUdpProxy::WSWriteText(const QString &Data)
{
    if (ws_) {
        ws_->sendTextMessage(Data);
        ws_->flush();
    }
}

void WsUdpProxy::WSWriteData(const QByteArray &Data)
{
    if (ws_) {
        ws_->sendBinaryMessage(Data);
        ws_->flush();
    }
}

static int create_udp_socket(const char *bind_addr, int src_port)
{
    int sockfd = socket(AF_INET, SOCK_DGRAM | SOCK_NONBLOCK, 0);
    if (sockfd < 0) {
        qCritical() << "create_udp_socket: socket creation failed:" << strerror(errno);
        return -1;
    }

    struct sockaddr_in servaddr;
    memset(&servaddr, 0, sizeof(servaddr));

    servaddr.sin_family = AF_INET; // IPv4
    if (bind_addr && *bind_addr != 0) {
        int res = inet_aton(bind_addr, &servaddr.sin_addr);
        if (res != 1) {
            close(sockfd);
            qCritical() << "create_udp_socket: inet_aton failed for address:" << bind_addr;
            return -1;
        }
    } else {
        servaddr.sin_addr.s_addr = INADDR_ANY;
    }
    servaddr.sin_port = htons(src_port);

    if (bind(sockfd, (const struct sockaddr *) &servaddr, sizeof(servaddr)) < 0) {
        qCritical() << "create_udp_socket: bind failed on port" << src_port << ":"
                    << strerror(errno);
        close(sockfd);
        return -1;
    }

    return sockfd;
}

WsUdpProxy::WsUdpProxy(const Config &config)
    : config_(config)
    , webSocketServer_(nullptr)
    , ws_(nullptr)
    , udpThread_(nullptr)
{
    for (int i = 0; i < socks_.size(); i++) {
        qDebug() << "Binding UDP to" << config_.base_port + i;
        socks_[i] = create_udp_socket(config.base_bind_addr.toLatin1(), config.base_port + i);
        if (socks_[i] < 0) {
            qCritical() << "Failed to create UDP socket" << i;
            // Clean up already created sockets
            for (int j = 0; j < i; j++) {
                close(socks_[j]);
                socks_[j] = -1;
            }
            return;
        }

        memset(&stoaddr_[i], 0, sizeof(stoaddr_[i]));
        stoaddr_[i].sin_family = AF_INET; // IPv4
        inet_aton(config.remote_addr.toLatin1(), &stoaddr_[i].sin_addr);
        stoaddr_[i].sin_port = htons(config.remote_port + i);
    }

    isClientMode_ = config.ws_port == 0;
    if (isClientMode_) {
        // client mode
        if (config.debug)
            qDebug() << "Connecting to WebSocket server:" << config_.ws_url
                     << " udp base port: " << config_.base_port;
        connect(&webSocket_, &QWebSocket::connected, this, &WsUdpProxy::onConnected);
        connect(&webSocket_, &QWebSocket::disconnected, this, &WsUdpProxy::onClosed);

        webSocket_.open(config.ws_url);
    } else {
        // server mode
        if (config.debug)
            qDebug() << "Creating WebSocket server on port:" << config.ws_port
                     << " udp base port: " << config.base_port
                     << " WS bind address: " << config.ws_bind_addr;
        webSocketServer_ = new QWebSocketServer(
            QStringLiteral("UDP Bridge Server"), QWebSocketServer::NonSecureMode, this);

        if (webSocketServer_->listen(config.ws_bind_addr.isEmpty()
                                         ? QHostAddress::Any
                                         : QHostAddress(config.ws_bind_addr),
                config.ws_port)) {
            if (config.debug)
                qDebug() << "WS listening on port" << config.ws_port;
            connect(webSocketServer_,
                &QWebSocketServer::newConnection,
                this,
                &WsUdpProxy::onNewConnection);
            connect(webSocketServer_, &QWebSocketServer::closed, this, &WsUdpProxy::onClosed);
        }
    }
}

WsUdpProxy::~WsUdpProxy()
{
    if (udpThread_) {
        udpThread_->requestInterruption();
        if (!udpThread_->wait(5000)) {
            udpThread_->terminate();
            udpThread_->wait();
        }
        delete udpThread_;
    }

    for (int fd : socks_) {
        if (fd >= 0) {
            close(fd);
        }
    }
}

void WsUdpProxy::socketDisconnected()
{
    if (udpThread_) {
        udpThread_->requestInterruption();
        if (!udpThread_->wait(5000)) {
            qWarning() << "UDP thread did not finish gracefully, terminating";
            udpThread_->terminate();
            udpThread_->wait();
        }
        delete udpThread_;
        udpThread_ = nullptr;
    }
    ws_ = nullptr;
}

void WsUdpProxy::onNewConnection()
{
    QWebSocket *pSocket = webSocketServer_->nextPendingConnection();

    // Only allow one connection at a time
    if (ws_ != nullptr) {
        qWarning() << "Rejecting connection - only 1 active connection allowed";
        pSocket->close();
        pSocket->deleteLater();
        return;
    }

    lastind.store(0);
    uint64_t dummy;
    getTimestamp(dummy);

    connect(pSocket, &QWebSocket::textMessageReceived, this, &WsUdpProxy::onTextMessageReceived);
    connect(pSocket, &QWebSocket::binaryMessageReceived, this, &WsUdpProxy::onBinaryMessageReceived);
    connect(pSocket, &QWebSocket::disconnected, this, &WsUdpProxy::socketDisconnected);

    constexpr int WS_READ_BUFFER_SIZE = 1024 * 1024;
    pSocket->setReadBufferSize(WS_READ_BUFFER_SIZE);

    ws_ = pSocket;
    udpThread_ = new UdpThread(this, socks_);
    udpThread_->start();
}

void WsUdpProxy::onConnected()
{
    if (config_.debug)
        qDebug() << "WebSocket connected";

    connect(&webSocket_, &QWebSocket::textMessageReceived, this, &WsUdpProxy::onTextMessageReceived);
    connect(
        &webSocket_, &QWebSocket::binaryMessageReceived, this, &WsUdpProxy::onBinaryMessageReceived);

    ws_ = &webSocket_;
    udpThread_ = new UdpThread(this, socks_);
    udpThread_->start();
}

void WsUdpProxy::onClosed()
{
    if (isClientMode_)
        qWarning() << "WebSocket closed";

    emit WsUdpProxy::closed();
}

void WsUdpProxy::onTextMessageReceived(QString message)
{
    if (config_.debug)
        qDebug() << "Message text received:" << message;

    int sockIdx = eOsmoSockets::CMD;
    QByteArray ba = message.toLatin1();
    uint64_t rtm;
    int64_t delta;
    const QString tm = getTimestamp(rtm);
    double fdelta;
    const char *buf = ba.data();

    if (strncmp(buf, "IND CLOCK", 9) == 0) {
        sockIdx = eOsmoSockets::CLOCK;
        //qWarning() << "sento IND CLOCK socket " << buf;
        const uint64_t lastValue = lastind.load();
        delta = rtm - lastValue;
        lastind.store(rtm);
        fdelta = delta / 1.0e9;
    } else {
        fdelta = 0;
    }

    qDebug() << tm << "=>" << ba
             << (sockIdx == eOsmoSockets::CLOCK ? "===========================" : "") << fdelta;

    int sz = ba.size();
    int res = sendto(socks_[sockIdx],
        buf,
        sz,
        MSG_DONTWAIT,
        (struct sockaddr *) &stoaddr_[sockIdx],
        sizeof(stoaddr_[sockIdx]));
    if (res < 0) {
        qWarning() << "sendto error:" << strerror(errno);
    }
}

void WsUdpProxy::onBinaryMessageReceived(const QByteArray &message)
{
    if (message.size() > 11) // skip all small buffers
        qDebug() << "Message binary received:" << message;

    const char *buf = message.data();
    int sz = message.size();
    int res = sendto(socks_[eOsmoSockets::DATA],
        buf,
        sz,
        0,
        (struct sockaddr *) &stoaddr_[eOsmoSockets::DATA],
        sizeof(stoaddr_[eOsmoSockets::DATA]));
    if (res < 0) {
        qWarning() << "sendto error:" << strerror(errno);
    }
}
