# FitStreak en Google Play: todo lo que hay que rellenar

Archivos de esta carpeta:
- `icon-512.png`: icono de la ficha (512×512).
- `feature-graphic-1024x500.png`: gráfico destacado.
- El AAB está en `D:\fitstreak\FitStreak-1.0.0.aab` (no se sube a git).

Enlaces:
- Política de privacidad: https://arturoces.github.io/fitstreak/privacy.html
- Borrar cuenta (URL que pide Play): https://arturoces.github.io/fitstreak/privacy.html#borrar

---

## 1. Crear la app (Play Console → Crear app)

| Campo | Valor |
|---|---|
| Nombre | FitStreak |
| Idioma predeterminado | Español (España) – es-ES |
| App o juego | App |
| Gratis o de pago | Gratis (no se puede cambiar a pago después) |

## 2. Ficha principal de Play Store

**Nombre (máx. 30):**
FitStreak: rutinas y racha

**Descripción breve (máx. 80):**
Tu rutina de gym o casa, serie a serie, con racha, progreso y resumen por voz.

**Descripción completa:**

FitStreak te crea una rutina a tu medida y te acompaña en cada serie para que no pierdas la racha.

💪 RUTINA A TU MEDIDA
• Dinos tus días por semana, tu objetivo, tu nivel y el material que tienes (gimnasio o casa) y FitStreak monta la rutina.
• ¿No te gusta un día? Cámbialo por otros ejercicios para los mismos músculos.
• Añade alternativas a cada ejercicio («fondos o extensión de tríceps») y elige cada día.
• ¿Ya tienes rutina? Pégala o ábrela desde un .docx y FitStreak la entiende.

🏋️ ENTRENO GUIADO
• Dibujos animados e instrucciones en español de cada ejercicio.
• Te propone lo que hiciste la última vez y te avisa cuando toca subir peso.
• Temporizador de descanso con aviso, que puedes minimizar para seguir viendo cómo se hace el ejercicio.
• Burbuja flotante con el tiempo mientras usas otras apps.

🔥 RACHA QUE ENTIENDE TUS DESCANSOS
• Los días de descanso de tu plan no rompen la racha.
• Gana protectores entrenando para los días que no puedas.
• Widget en la pantalla de inicio y recordatorios.

📈 PROGRESO
• Gráficas por ejercicio: peso máximo, 1RM estimado y volumen.
• Récords de la semana.

🍎 CALORÍAS CON HEALTH CONNECT
• Meta diaria calculada con tu perfil.
• Pasos y calorías de tu reloj, y lo que comes desde apps como Fitia.
• Tus entrenos se guardan en Health Connect.

🗣️ RESUMEN POR VOZ
• «Tu resumen» de hoy y de la semana, leído en voz alta.
• Atajos en el icono y aviso cada noche y los domingos.

👥 COMPARTE TU RUTINA
• Mándala por WhatsApp con un enlace o un código.
• Publícala para que otros la sigan y reciban tus cambios.

Sin anuncios. Tus datos se quedan en tu móvil.

**Gráficos:** sube `icon-512.png` y `feature-graphic-1024x500.png`.

**Capturas de teléfono (mín. 2, recomendadas 4-8):** hazlas desde tu móvil, por ejemplo:
1. La pantalla de rutina con el día de hoy.
2. Un ejercicio durante el entreno (con el dibujo).
3. El descanso.
4. La racha o el calendario.
5. Progreso de un ejercicio.
6. «Tu resumen».

**Categoría:** Salud y forma física. **Email de contacto:** arturoc200212@gmail.com.

---

## 3. Contenido de la app (Panel → Contenido de la app)

### Política de privacidad
`https://arturoces.github.io/fitstreak/privacy.html`

### Acceso a la app
"Todas las funciones están disponibles sin restricciones de acceso" (no hace falta iniciar sesión).

### Anuncios
"No, mi app no contiene anuncios".

### Clasificación de contenido
- Categoría: **Todas las demás categorías de apps** (no es juego ni red social).
- Violencia, sexo, lenguaje, drogas, apuestas: **No** a todo.
- ¿Los usuarios interactúan o comparten contenido? **Sí**: pueden publicar rutinas con un nombre de autor que se ven por código o en el buscador. (No hay chat ni mensajes.)
- ¿Comparte la ubicación? **No**. ¿Compras digitales? **No**.

### Público objetivo
- Edades: **18 y más** (o 13-17 y 18+; nunca menores de 13).
- ¿Puede atraer a niños? **No**.

### App de noticias / gubernamental / préstamos
**No** en todas.

### Apps de salud (formulario "Health apps")
- Marca **Fitness / actividad física** (seguimiento de entrenos, calorías).
- No es dispositivo médico ni ofrece diagnóstico.

### Seguridad de los datos

¿Recoge o comparte datos? **Sí**. ¿Cifrados en tránsito? **Sí** (HTTPS). ¿Se pueden borrar? **Sí** (en la app y con la URL de borrado).

Datos **recogidos** (salen del móvil hacia Supabase, solo si publicas o sigues una rutina):

| Tipo | Dato | Obligatorio | Para qué |
|---|---|---|---|
| Información personal | Nombre (el de autor que escribas) | Opcional | Funcionalidad de la app |
| Información personal | Dirección de email | Opcional | Gestión de la cuenta |
| Información personal | ID de usuario (cuenta anónima) | Opcional | Funcionalidad, gestión de cuenta |
| Actividad en la app | Otro contenido generado por el usuario (la rutina publicada) | Opcional | Funcionalidad de la app |

Datos **compartidos** con terceros: **ninguno**.

Lo de Health Connect, el perfil (peso, edad…) y el historial **no** se declara como recogido porque nunca sale del dispositivo (Google solo pide declarar lo que se transmite fuera).

### Health Connect (Contenido de la app → Permisos de Health Connect)

Justificación por permiso:

| Permiso | Justificación |
|---|---|
| READ_STEPS | Mostrar los pasos del día en la tarjeta de energía junto a la meta de calorías. |
| READ_ACTIVE_CALORIES_BURNED | Calcular las calorías gastadas hoy frente a la meta diaria. |
| READ_TOTAL_CALORIES_BURNED | Igual que el anterior, cuando el reloj solo da el total. |
| READ_NUTRITION | Mostrar las calorías comidas hoy (apuntadas en apps como Fitia) frente a la meta. |
| WRITE_EXERCISE | Guardar en Health Connect los entrenos terminados en FitStreak. |
| WRITE_TOTAL_CALORIES_BURNED | Guardar las calorías estimadas de cada entreno. |

Indica que los datos solo se muestran en la app, no se envían a servidores ni se usan para publicidad.

### Servicio en primer plano (Foreground service: specialUse)
- Tipo: **Special use**.
- Descripción: "La burbuja flotante con el cronómetro del entreno se dibuja sobre otras apps mientras el usuario entrena y cambia de app (por ejemplo para poner música). El servicio solo corre mientras hay un entreno en marcha y el usuario ha activado la burbuja; al tocarla vuelve a la app."
- Vídeo: graba la pantalla (15-30 s): empiezas un entreno, sales al inicio, aparece la burbuja, la mueves y al tocarla vuelves al entreno. Súbelo a YouTube como "No listado" y pega el enlace.

### Permiso de superposición (SYSTEM_ALERT_WINDOW)
Si lo pregunta: "Muestra el temporizador del entreno sobre otras apps; el usuario lo activa a mano y se pide el permiso con una explicación."

### Alarmas exactas
No hace falta declarar nada: la app usa SCHEDULE_EXACT_ALARM, no USE_EXACT_ALARM.

---

## 4. Prueba cerrada (obligatoria en cuentas personales nuevas)

1. Pruebas → Prueba cerrada → Crear canal → sube `FitStreak-1.0.0.aab`.
2. Testers: crea una lista de emails (cuentas de Google) con **al menos 12 personas**.
3. Comparte el enlace de inscripción; cada uno debe aceptar e instalar desde Play.
4. Mantén a los 12 durante **14 días seguidos**.
5. Después: Panel → "Solicitar acceso a producción" y responde el cuestionario sobre la prueba.

## 5. Cada actualización

1. Sube la versión en `pubspec.yaml` (`1.0.0+1` → `1.0.1+2`; el número tras el `+` siempre tiene que subir).
2. `flutter build appbundle --release`
3. Sube el AAB nuevo en el canal que toque.

## Keystore (¡no lo pierdas!)

- Clave: `D:\fitstreak-keys\upload-keystore.jks`
- Contraseñas: `D:\fitstreak-keys\key.properties` (copia también en `android/key.properties`)
- Haz copia de esa carpeta en Drive o un USB. Al usar "Firma de apps de Google Play" (recomendado y por defecto), si la pierdes se puede pedir a Google un reseteo de la clave de subida, pero tarda días.
