import admin from 'firebase-admin';
import { getFirestore, collection, query, where, onSnapshot, updateDoc, doc } from 'firebase/firestore';

/**
 * Firebase Realtime Listener
 * Monitors Firestore for missed medicines and triggers WhatsApp alerts
 */

interface MedicineLog {
  id: string;
  userId: string;
  slot: string;
  taken: boolean;
  missed: boolean;
  whatsappSent: boolean;
  timestamp?: Date;
}

/**
 * Set up listener for missed medicines
 * When a medicine is marked as missed and WhatsApp hasn't been sent yet,
 * trigger the alert
 */
export function setupMissedMedicineListener(
  onMissedMedicine: (log: MedicineLog, userPhone: string, userName: string) => Promise<void>
) {
  const db = getFirestore();

  // Listen for documents where missed=true and whatsappSent=false
  const q = query(
    collection(db, 'medicineLogs'),
    where('missed', '==', true),
    where('whatsappSent', '==', false)
  );

  const unsubscribe = onSnapshot(q, async (snapshot) => {
    for (const docSnap of snapshot.docs) {
      const medicineLog = docSnap.data() as MedicineLog;
      medicineLog.id = docSnap.id;

      try {
        // Get user details (name, phone)
        const userRef = doc(db, 'users', medicineLog.userId);
        const userSnap = await admin.firestore().doc(`users/${medicineLog.userId}`).get();
        
        if (!userSnap.exists) {
          console.warn(`User ${medicineLog.userId} not found`);
          return;
        }

        const userData = userSnap.data();
        const userPhone = userData?.parentPhone || '';
        const userName = userData?.name || 'User';

        // Call the WhatsApp alert function
        await onMissedMedicine(medicineLog, userPhone, userName);

      } catch (error) {
        console.error(`Error processing missed medicine ${medicineLog.id}:`, error);
      }
    }
  });

  return unsubscribe;
}

/**
 * Mark medicine log as WhatsApp sent to prevent duplicates
 */
export async function markWhatsappAsSent(logId: string): Promise<void> {
  try {
    const db = admin.firestore();
    await db.collection('medicineLogs').doc(logId).update({
      whatsappSent: true,
      updatedAt: new Date(),
    });
    console.log(`Marked log ${logId} as WhatsApp sent`);
  } catch (error) {
    console.error(`Error marking log ${logId} as sent:`, error);
    throw error;
  }
}

/**
 * Get all pending missed medicine alerts
 */
export async function getPendingMissedMedicines(): Promise<MedicineLog[]> {
  try {
    const db = admin.firestore();
    const snapshot = await db
      .collection('medicineLogs')
      .where('missed', '==', true)
      .where('whatsappSent', '==', false)
      .limit(100)
      .get();

    return snapshot.docs.map((doc) => {
      const data = doc.data();
      return {
        id: doc.id,
        userId: data.userId,
        slot: data.slot,
        taken: data.taken,
        missed: data.missed,
        whatsappSent: data.whatsappSent,
        timestamp: data.timestamp?.toDate(),
      } as MedicineLog;
    });
  } catch (error) {
    console.error('Error getting pending missed medicines:', error);
    throw error;
  }
}

/**
 * Get user by ID
 */
export async function getUser(userId: string): Promise<any> {
  try {
    const db = admin.firestore();
    const doc = await db.collection('users').doc(userId).get();
    return doc.data();
  } catch (error) {
    console.error(`Error getting user ${userId}:`, error);
    throw error;
  }
}
