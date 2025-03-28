const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

admin.initializeApp();

exports.notifyStudentOnNewVisit = functions.firestore
    .document("visitas/{visitaId}")
    .onCreate(async (snap, context) => {
      const nuevaVisita = snap.data();
      if (!nuevaVisita || !nuevaVisita.alumnos) {
        console.log("No hay alumnos en la visita");
        return null;
      }
      const tokens = [];
      for (const alumnoId of nuevaVisita.alumnos) {
        const alumnoDoc = await admin.firestore()
            .collection("alumnos").doc(alumnoId).get();
        if (alumnoDoc.exists && alumnoDoc.data().fcmToken) {
          tokens.push(alumnoDoc.data().fcmToken);
        }
      }

      if (tokens.length === 0) {
        console.log("No se encontraron tokens de alumnos.");
        return null;
      }
      const payload = {
        notification: {
          title: "Nueva Visita Escolar",
          body: `Tienes una nueva visita a ${nuevaVisita.empresa}.`,
        },
      };
      try {
        await admin.messaging().sendToDevice(tokens, payload);
        console.log("Notificación enviada con éxito.");
      } catch (error) {
        console.error("Error al enviar la notificación:", error);
      }
      return null;
    });
