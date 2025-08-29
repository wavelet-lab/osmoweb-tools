#ifndef WS_UDP_PROXY_H
#define WS_UDP_PROXY_H

#include <netinet/in.h>
#include <QtCore/QDebug>
#include <QtCore/QObject>
#include <QtCore/QThread>
#include <QtWebSockets/QWebSocket>
#include <QtWebSockets/QWebSocketServer>

enum eOsmoSockets { CLOCK, CMD, DATA, SocketsCount };
using OsmoSocketFds = std::array<int, eOsmoSockets::SocketsCount>;

class WsUdpProxy;
class UdpThread : public QThread
{
    Q_OBJECT
public:
    explicit UdpThread(WsUdpProxy *skt, OsmoSocketFds fds);
    ~UdpThread() override = default;

    void run() override;

private:
    // Config
    int loglevel_;

    // Sockets
    OsmoSocketFds fds_;

    // Threading
    WsUdpProxy *wsThread_;

public:
Q_SIGNALS:
    void WSWriteText(const QString &Data);
    void WSWriteData(const QByteArray &Data);
};

class WsUdpProxy : public QObject
{
    Q_OBJECT
public:
    struct Config
    {
        int base_port;
        QString base_bind_addr;
        int remote_port;
        QString remote_addr;
        int ws_port;
        QString ws_url;
        QString ws_bind_addr;
        bool debug;
    };

    static const Config defaultConfig;

public:
    explicit WsUdpProxy(const Config &config);
    ~WsUdpProxy();

Q_SIGNALS:
    void closed();

private Q_SLOTS:
    void onConnected();
    void onClosed();
    void onTextMessageReceived(QString message);
    void onBinaryMessageReceived(const QByteArray &message);
    void onNewConnection();
    void socketDisconnected();

public Q_SLOTS:
    void WSWriteText(const QString &Data);
    void WSWriteData(const QByteArray &Data);

private:
    QWebSocketServer *webSocketServer_;
    QWebSocket *ws_;
    QWebSocket webSocket_;

    // Config
    Config config_;
    bool isClientMode_;

    // UDP sockets and addressing
    OsmoSocketFds socks_;
    std::array<sockaddr_in, eOsmoSockets::SocketsCount> stoaddr_;

    // Threading
    UdpThread *udpThread_;
};

#endif // WS_UDP_PROXY_H
