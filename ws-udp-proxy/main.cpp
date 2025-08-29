#include "ws_udp_proxy.h"
#include <QtCore/QCommandLineOption>
#include <QtCore/QCommandLineParser>
#include <QtCore/QCoreApplication>

int main(int argc, char *argv[])
{
    QCoreApplication a(argc, argv);

    QCommandLineParser parser;
    parser.setApplicationDescription("QtWebSockets example: echoclient");
    parser.addHelpOption();

    QCommandLineOption basePortOption(QStringList() << "p" << "base-port",
        QCoreApplication::translate("main", "UDP base port [5000] (binding on)"),
        QCoreApplication::translate("main", "base-port"),
        QLatin1String("5000"));
    QCommandLineOption remotePortOption(QStringList() << "r" << "remote-port",
        QCoreApplication::translate("main", "UDP base remote port [6000] (sending data to)"),
        QCoreApplication::translate("main", "remote-port"),
        QLatin1String("6000"));
    QCommandLineOption wsPortOption(QStringList() << "l" << "ws-port",
        QCoreApplication::translate("main", "Listen WS server on port"),
        QCoreApplication::translate("main", "ws-port"),
        QLatin1String("0"));
    QCommandLineOption wsUrlOption(QStringList() << "u" << "ws-url",
        QCoreApplication::translate("main", "Connect to WS"),
        QCoreApplication::translate("main", "ws-url"),
        QLatin1String("ws://127.0.0.1:8880"));
    QCommandLineOption wsBindOption(QStringList() << "b" << "ws-bind",
        QCoreApplication::translate("main", "Connect to WS"),
        QCoreApplication::translate("main", "ws-bind"),
        QLatin1String("127.0.0.1"));
    QCommandLineOption dbgOption(QStringList() << "d" << "debug",
        QCoreApplication::translate("main", "Debug output [default: off]."));

    parser.addOption(basePortOption);
    parser.addOption(remotePortOption);
    parser.addOption(wsPortOption);
    parser.addOption(wsUrlOption);
    parser.addOption(wsBindOption);
    parser.addOption(dbgOption);

    parser.process(a);
    WsUdpProxy::Config config = WsUdpProxy::defaultConfig;
    config.base_port = parser.value(basePortOption).toUShort();
    config.remote_port = parser.value(remotePortOption).toUShort();
    config.ws_port = parser.value(wsPortOption).toUShort();
    config.ws_url = parser.value(wsUrlOption);
    config.ws_bind_addr = parser.value(wsBindOption);
    config.debug = parser.isSet(dbgOption);

    WsUdpProxy ws_udp_proxy(config);
    QObject::connect(&ws_udp_proxy, &WsUdpProxy::closed, &a, &QCoreApplication::quit);

    return a.exec();
}
