import 'dotenv/config';
import admin from 'firebase-admin';
import fs from 'fs';
import path from 'path';
import { logger } from './logger.js';
import {
  setupMissedMedicineListener,
  markWhatsappAsSent,
  getUser,
} from './firebase.js';
import {
  initializeWhatsAppClient,
  sendWhatsAppMessage,
  closeWhatsAppClient,
  isWhatsAppReady,
} from './whatsapp.js';

/**
 * Main Entry Point
 * Medicine Tracker WhatsApp Bot
 *
 * Flow:
 * 1. Initialize Firebase Admin
 * 2. Initialize WhatsApp Web.js Client (with QR login)
 * 3. Listen to Firestore for missed medicines
 * 4. Send WhatsApp alerts to parent phone
 * 5. Mark alerts as sent to prevent duplicates
 */

// Firebase initialization
function initializeFirebase(): void {
  try {
    const credentialsPath =
      process.env.FIREBASE_CREDENTIALS_PATH || './firebase-credentials.json';

    if (!fs.existsSync(credentialsPath)) {
      logger.error(
        `Firebase credentials not found at ${credentialsPath}. See README for setup.`
      );
      process.exit(1);
    }

    const serviceAccount = JSON.parse(fs.readFileSync(credentialsPath, 'utf-8'));

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id,
    });

    logger.info('✅ Firebase Admin initialized');
  } catch (error) {
    logger.error(`❌ Error initializing Firebase: ${error}`);
    process.exit(1);
  }
}

// Create logs directory if it doesn't exist
function ensureLogsDirectory(): void {
  const logsDir = path.join(process.cwd(), 'logs');
  if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
  }
}

/**
 * Handle missed medicine alert
 * Called when Firestore detects a missed medicine
 */
async function handleMissedMedicine(
  medicineLog: any,
  parentPhone: string,
  userName: string
): Promise<void> {
  try {
    if (!parentPhone) {
      logger.warn(
        `No parent phone configured for user ${medicineLog.userId}`
      );
      return;
    }

    // Get slot times from user profile
    const user = await getUser(medicineLog.userId);
    const slot = user?.slots?.[medicineLog.slot];
    const timeRange = slot
      ? `${slot.startTime} - ${slot.endTime}`
      : medicineLog.slot;

    // Compose WhatsApp message
    const message = `🚨 *Medicine Alert*\n\n${userName} did NOT take *${medicineLog.slot.charAt(0).toUpperCase() + medicineLog.slot.slice(1)} Medicine* between ${timeRange}.\n\nPlease remind them to take their medicine.`;

    // Send via WhatsApp
    const sent = await sendWhatsAppMessage(parentPhone, message);

    if (sent) {
      // Mark as sent in Firestore to prevent duplicates
      await markWhatsappAsSent(medicineLog.id);
      logger.info(
        `✅ Alert sent to ${parentPhone} for user ${userName} (${medicineLog.slot})`
      );
    } else {
      logger.error(
        `❌ Failed to send alert to ${parentPhone} for user ${userName}`
      );
    }
  } catch (error) {
    logger.error(`Error handling missed medicine: ${error}`);
  }
}

/**
 * Graceful shutdown
 */
async function shutdown(): Promise<void> {
  logger.info('Shutting down gracefully...');
  try {
    await closeWhatsAppClient();
    process.exit(0);
  } catch (error) {
    logger.error(`Error during shutdown: ${error}`);
    process.exit(1);
  }
}

/**
 * Main function
 */
async function main(): Promise<void> {
  ensureLogsDirectory();

  logger.info('🚀 Medicine Tracker WhatsApp Bot Starting...');

  // Initialize Firebase
  initializeFirebase();

  // Initialize WhatsApp
  try {
    logger.info('Initializing WhatsApp client...');
    await initializeWhatsAppClient();
  } catch (error) {
    logger.error(`❌ Failed to initialize WhatsApp: ${error}`);
    process.exit(1);
  }

  // Set up Firestore listener for missed medicines
  if (isWhatsAppReady()) {
    logger.info('Setting up missed medicine listener...');
    setupMissedMedicineListener(handleMissedMedicine);
    logger.info('✅ Listening for missed medicines...');
  } else {
    logger.error('WhatsApp client not ready, cannot set up listener');
    process.exit(1);
  }

  // Handle graceful shutdown
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);

  logger.info('🎉 Bot is running and ready to send alerts!');
}

// Run the bot
main().catch((error) => {
  logger.error(`Fatal error: ${error}`);
  process.exit(1);
});
