import { Client, LocalAuth, Message } from 'whatsapp-web.js';
import qrcode from 'qrcode-terminal';
import { logger } from './logger.js';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * WhatsApp Web.js Service
 * Handles WhatsApp client initialization, authentication, and message sending
 */

let client: Client | null = null;
let isClientReady = false;

/**
 * Initialize WhatsApp client
 * Uses local authentication to stay logged in
 */
export async function initializeWhatsAppClient(): Promise<Client> {
  return new Promise((resolve, reject) => {
    try {
      client = new Client({
        authStrategy: new LocalAuth({
          clientId: 'medicine-bot',
          dataPath: process.env.WHATSAPP_SESSION_DIR || './whatsapp-session',
        }),
        puppeteer: {
          args: ['--no-sandbox', '--disable-setuid-sandbox'],
          headless: true,
        },
      });

      // QR Code for initial login
      client.on('qr', (qr: string) => {
        logger.info('QR Code received. Scan with WhatsApp to authenticate:');
        qrcode.generate(qr, { small: true });
      });

      // Client ready
      client.on('ready', () => {
        isClientReady = true;
        logger.info('✅ WhatsApp client is ready');
        resolve(client!);
      });

      // Message received (for debugging)
      client.on('message', (message: Message) => {
        logger.debug(`Message from ${message.from}: ${message.body}`);
      });

      // Client disconnect
      client.on('disconnected', () => {
        isClientReady = false;
        logger.warn('⚠️ WhatsApp client disconnected');
      });

      // Authentication failure
      client.on('auth_failure', () => {
        logger.error('❌ WhatsApp authentication failed');
        reject(new Error('WhatsApp authentication failed'));
      });

      // Errors
      client.on('error', (error) => {
        logger.error(`WhatsApp client error: ${error.message}`);
      });

      client.initialize().catch(reject);
    } catch (error) {
      logger.error(`Error initializing WhatsApp client: ${error}`);
      reject(error);
    }
  });
}

/**
 * Send WhatsApp message
 * @param phoneNumber - Recipient phone number (with country code, e.g., +1234567890)
 * @param message - Message text
 */
export async function sendWhatsAppMessage(
  phoneNumber: string,
  message: string
): Promise<boolean> {
  if (!client || !isClientReady) {
    logger.error('WhatsApp client not ready');
    return false;
  }

  try {
    // Format phone number for WhatsApp
    const chatId = phoneNumber.includes('@') ? phoneNumber : `${phoneNumber}@c.us`;

    logger.info(`Sending WhatsApp to ${phoneNumber}: ${message.substring(0, 50)}...`);

    const result = await client.sendMessage(chatId, message);

    logger.info(`✅ Message sent to ${phoneNumber}`);
    return true;
  } catch (error) {
    logger.error(`Error sending WhatsApp message to ${phoneNumber}: ${error}`);
    return false;
  }
}

/**
 * Close WhatsApp client
 */
export async function closeWhatsAppClient(): Promise<void> {
  if (client) {
    try {
      await client.destroy();
      isClientReady = false;
      logger.info('WhatsApp client closed');
    } catch (error) {
      logger.error(`Error closing WhatsApp client: ${error}`);
    }
  }
}

/**
 * Check if client is ready
 */
export function isWhatsAppReady(): boolean {
  return isClientReady && client !== null;
}

/**
 * Get current WhatsApp account info
 */
export async function getWhatsAppInfo(): Promise<any> {
  if (!client || !isClientReady) {
    return null;
  }

  try {
    return await client.getWWebVersion();
  } catch (error) {
    logger.error(`Error getting WhatsApp info: ${error}`);
    return null;
  }
}
