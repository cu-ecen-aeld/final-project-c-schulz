#include <syslog.h>
#include <csignal>
#include <atomic>
#include "mqtt/async_client.h"

// mqtt settings
const std::string MQTT_CLIENT_ID{"mqtt-event-logger"};
const std::string MQTT_DEFAULT_HOST{"mqtt://localhost:1883"};
const std::string MQTT_DEFAULT_TOPIC{"#"};

const int MQTT_QOS = 1;
const int MQTT_RETRY_ATTEMPTS = 5;


class MQTTListener : public virtual mqtt::iaction_listener
{
    std::string name_;

    void on_failure(const mqtt::token& tok) override
    {
        std::string msg{""};
        if (tok.get_message_id())
            msg += " for token: [" + std::to_string(tok.get_message_id()) + "]";

        syslog(LOG_DEBUG, "Failure of listener '%s'%s", name_.c_str(), msg.c_str());
    }

    void on_success(const mqtt::token& tok) override
    {
        std::string msg{""};
        if (tok.get_message_id())
            msg += " for token: [" + std::to_string(tok.get_message_id()) + "]";
        const auto& top = tok.get_topics();
        if (top && !top->empty()) {
            msg += "; Token topics: ";
            for (const auto& t : *top)
                msg += "'" + t + "', ";
        }

        syslog(LOG_DEBUG, "Success of listener '%s'%s", name_.c_str(), msg.c_str());
    }

public:
    MQTTListener(const std::string& name) : name_(name) {}
};

class MQTTClient : public virtual mqtt::callback, public virtual mqtt::iaction_listener
{
    mqtt::async_client client_;
    mqtt::connect_options connOpts_;
    MQTTListener listener_;

    std::string topic_;
    int nretry_;

public:
    MQTTClient(const std::string& mqtt_host, const std::string& mqtt_client_id, const std::string& mqtt_topic) :
        client_{mqtt_host, mqtt_client_id},
        connOpts_{},
        listener_{"MQTT Subscriber"},
        topic_{mqtt_topic},
        nretry_{0}
    {
        syslog(LOG_INFO, "Instantiating MQTT client connecting to MQTT server at '%s' with id '%s'.", mqtt_host.c_str(), mqtt_client_id.c_str());
        connOpts_.set_clean_session(false);
        client_.set_callback(*this);
    }

    // connect the mqtt client
    bool connect()
    {
        try {
            syslog(LOG_INFO, "Connecting to MQTT server...");
            client_.connect(connOpts_, nullptr, *this);
        }
        catch (const mqtt::exception& e) {
            syslog(LOG_ERR, "Unable to connect to MQTT server: %s", e.what());
            return false;
        }
        return true;
    }

    // disconnect the mqtt client
    bool disconnect()
    {
        try {
            syslog(LOG_INFO, "Disconnecting from MQTT server...");
            client_.disconnect()->wait();
            syslog(LOG_INFO, "Disconnected.");
        }
        catch (const mqtt::exception& e) {
            syslog(LOG_ERR, "Unable to disconnect from MQTT server: %s", e.what());
            return false;
        }
        return true;
    }

    // reconnect the mqtt client
    void reconnect()
    {
        std::this_thread::sleep_for(std::chrono::milliseconds(2500));
        if (!connect())
            exit(1);
    }

    // (re-)connection failure callback, triggers reconnect attempt
    void on_failure(const mqtt::token& tok) override
    {
        if (++nretry_ > MQTT_RETRY_ATTEMPTS) {
            syslog(LOG_ERR, "Connection attempt finally failed.");
            exit(1);
        }
        syslog(LOG_ERR, "Connection attempt failed. Retrying...");
        reconnect();
    }

    // (re-)connection success callback
    void on_success(const mqtt::token& tok) override {}

    // (re-)connection success callback, triggers subscription
    void connected(const std::string& cause) override
    {
        syslog(LOG_INFO, "Successfully connected. Subscribing to topic '%s'...", topic_.c_str());
        client_.subscribe(topic_, MQTT_QOS, nullptr, listener_);
    }

    // connection lost callback, triggers reconnect attempt
    void connection_lost(const std::string& cause) override
    {
        syslog(LOG_ERR, "Connection lost. Cause: %s", cause.c_str());
        nretry_ = 0;
        reconnect();
    }

    // message arrived callback
    void message_arrived(mqtt::const_message_ptr msg) override
    {
        syslog(LOG_INFO, "Message arrived. Topic: '%s'. Payload: '%s'", msg->get_topic().c_str(), msg->to_string().c_str());
    }

    // delivery complete callback
    void delivery_complete(mqtt::delivery_token_ptr token) override {}
};

// signal handler, needs 'extern "C"' according to standard
std::atomic<int> STOP_SIGNAL = -1;
extern "C" void signal_handler(int signum) {
    STOP_SIGNAL.store(signum);
}

// main function
int main(int argc, char* argv[])
{
    const std::string usage = "mqtt_subscriber -h <host> -t <topic> -d";

    // open syslog
    openlog(NULL, 0, LOG_USER);

    // set configuration options to default values
    std::string mqtt_client_id = MQTT_CLIENT_ID;
    std::string mqtt_host      = MQTT_DEFAULT_HOST;
    std::string mqtt_topic     = MQTT_DEFAULT_TOPIC;
    bool daemon_mode           = false;

    // parse command line arguments
    for (int i=1; i<argc; ++i) {
        if (std::string(argv[i]) == "-d")
            daemon_mode = true;
        else if (std::string(argv[i]) == "-h") {
            if (i < argc-1)
                mqtt_host = argv[i+1];
            else {
                syslog(LOG_ERR, "Error parsing command line arguments. Usage: %s", usage.c_str());
                return 1;
            }
        }
        else if (std::string(argv[i]) == "-t") {
            if (i < argc-1)
                mqtt_topic = argv[i+1];
            else {
                syslog(LOG_ERR, "Error parsing command line arguments. Usage: %s", usage.c_str());
                return 1;
            }
        }
    }

    // print daemon mode
    if (daemon_mode)
        syslog(LOG_INFO, "Starting in daemon mode...");

    // setup signal handler
    std::signal(SIGTERM, &signal_handler);
    std::signal(SIGINT,  &signal_handler);

    // create mqtt client
    MQTTClient mqtt_client(mqtt_host, mqtt_client_id, mqtt_topic);

    // connect the mqtt client
    if (!mqtt_client.connect())
        return 1;

    // block until user quits
    while (STOP_SIGNAL == -1);

    // print termination reason
    switch (STOP_SIGNAL) {
        case SIGTERM:
            syslog(LOG_DEBUG, "Terminated by SIGTERM.");
            break;
        case SIGINT:
            syslog(LOG_DEBUG, "Terminated by SIGINT.");
            break;
        default:
            syslog(LOG_DEBUG, "Terminated by unknown.");
    }

    // disconnect the mqtt client
    if (!mqtt_client.disconnect())
        return 1;

    closelog();

    return 0;
}