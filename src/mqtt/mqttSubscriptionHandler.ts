import { MqttClient, connect as mqttConnect, IClientOptions } from 'mqtt';
import { IKHomeBridgeHomebridgePlatform } from '../platform';
import { MultiServiceAccessory } from '../multiServiceAccessory';
import { ShortEvent } from '../webhook/subscriptionHandler';
import { Logger, PlatformConfig } from 'homebridge';

export class MqttSubscriptionHandler {
  private config: PlatformConfig;
  private devices: MultiServiceAccessory[] = [];
  private log: Logger;

  private client: MqttClient | null = null;
  private shutdown = false;

  private topicPrefix: string;

  constructor(platform: IKHomeBridgeHomebridgePlatform, devices: MultiServiceAccessory[]) {
    this.config = platform.config;
    this.log = platform.log;
    this.devices = devices;

    this.topicPrefix = (this.config.MqttTopicPrefix as string) || 'smartthings';
  }

  async startService(): Promise<void> {
    this.log.info('Starting MQTT subscription handler');

    const brokerUrl = this.config.MqttBroker as string;
    if (!brokerUrl) {
      this.log.error('MqttBroker is configured but empty');
      return;
    }

    const options: IClientOptions = {
      reconnectPeriod: 5000,
      connectTimeout: 10000,
    };

    const username = this.config.MqttUsername as string | undefined;
    const password = this.config.MqttPassword as string | undefined;
    if (username) options.username = username;
    if (password) options.password = password;

    this.client = mqttConnect(brokerUrl, options);

    this.client.on('connect', () => {
      this.log.info(`Connected to MQTT broker at ${brokerUrl}`);
      const topic = `${this.topicPrefix}/events/#`;
      this.client!.subscribe(topic, { qos: 1 }, (err) => {
        if (err) {
          this.log.error(`Failed to subscribe to ${topic}: ${err.message}`);
        } else {
          this.log.info(`Subscribed to ${topic}`);
        }
      });
    });

    this.client.on('message', (topic: string, payload: Buffer) => {
      try {
        const event = JSON.parse(payload.toString()) as ShortEvent;

        if (!event.deviceId || !event.capability || !event.attribute) {
          this.log.debug(`Ignoring malformed MQTT event on ${topic}`);
          return;
        }

        const device = this.devices.find(d => d.id === event.deviceId);
        if (device) {
          this.log.debug(`MQTT event for ${device.name || event.deviceId}: ${event.capability}.${event.attribute} = ${event.value}`);
          device.processEvent(event);
        } else {
          this.log.debug(`Received event for unknown device ${event.deviceId}`);
        }
      } catch (err: any) {
        this.log.error(`Error processing MQTT message on ${topic}: ${err.message || err}`);
      }
    });

    this.client.on('error', (err) => {
      this.log.error(`MQTT error: ${err.message}`);
    });

    this.client.on('reconnect', () => {
      this.log.warn('Reconnecting to MQTT broker...');
    });

    this.client.on('close', () => {
      this.log.warn('MQTT connection closed');
    });
  }

  stopService(): void {
    this.shutdown = true;
    if (this.client) {
      this.log.info('Stopping MQTT subscription handler');
      this.client.end(false, () => {
        this.log.debug('MQTT client ended');
      });
      this.client = null;
    }
  }
}
