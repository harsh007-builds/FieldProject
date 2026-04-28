# 🌿 AVANI — Smart Building Waste Management System

A full-stack application for digitizing and optimizing municipal waste management operations, built for **BMC (Brihanmumbai Municipal Corporation)** workflows.

Avani enables real-time waste tracking, performance-based billing (PAYT — Pay As You Throw), smart cleaner assignment, and inter-role communication between BMC Admins, Building Admins, and Field Cleaners.

---

## 📐 Architecture

```
FieldProject02/
├── backend/          # Node.js + Express + MongoDB REST API
├── frontend/         # Flutter (Dart) cross-platform mobile app
└── README.md
```

| Layer      | Stack                                      |
| ---------- | ------------------------------------------ |
| **Frontend** | Flutter, Provider, Firebase Auth, fl_chart |
| **Backend**  | Node.js, Express, Mongoose, MongoDB Atlas  |
| **Auth**     | Firebase Authentication + MongoDB lookup   |
| **Deploy**   | Render (backend), APK (frontend)           |

---

## ✨ Features

### 🏛️ BMC Admin Dashboard
- **System Overview** — live metrics for buildings, green scores, waste volumes, and cleaner count
- **Active Alerts** — real-time alerts for critical green scores and missed waste collections
- **Send Warnings** — send official warnings to underperforming buildings with optional notes
- **Smart Complaint Triage** — assign complaints to cleaners based on workload; live status tracking (Pending → Assigned → Resolved)
- **Leaderboard** — rank buildings by green score
- **Cleaner Management** — register, view, and monitor field cleaners
- **Building Management** — create buildings, assign cleaners, suspend/activate
- **Pricing Engine** — configure per-kg rates for wet, dry, and reject waste
- **Compliance Export** — download CSV/PDF reports

### 🏢 Building Admin Dashboard
- **Green Score Gauge** — semi-circular gauge showing environmental performance
- **Waste Distribution** — donut chart breakdown (wet/dry/reject)
- **Financial Overview** — estimated monthly bill with penalty alerts
- **BMC Warnings** — receive and acknowledge warnings from BMC with unread badges
- **Raise Complaints** — submit categorized complaints to BMC
- **Smart Insights** — AI-driven suggestions based on waste patterns

### 🧹 Cleaner Dashboard
- **Log Daily Waste** — record wet, dry, and reject waste per building
- **Assigned Tasks** — view complaints assigned by BMC Admin
- **Mark Resolved** — resolve tasks, auto-updating BMC Admin's dashboard in real-time

### 🔐 Authentication
- Firebase Auth for login (email/password)
- Backend handshake maps email → MongoDB role (`BMC_ADMIN`, `BUILDING_ADMIN`, `CLEANER`)
- Role-based navigation to the correct dashboard
- Logout from any dashboard returns to login

---

## 🚀 Getting Started

### Prerequisites
- **Node.js** v18+
- **Flutter** v3.x
- **MongoDB Atlas** cluster (or local MongoDB)
- **Firebase** project with Authentication enabled

### Backend Setup

```bash
cd backend
npm install
```

Create a `.env` file:
```env
MONGODB_URI=mongodb+srv://<user>:<pass>@cluster.mongodb.net/<db>
PORT=3000
```

Start the server:
```bash
node server.js
```

### Frontend Setup

```bash
cd frontend
flutter pub get
```

Update `lib/utils/constants.dart` with your backend URL:
```dart
const String baseUrl = 'http://localhost:3000/api';
```

Run on Chrome or device:
```bash
flutter run -d chrome
# or
flutter build apk --release --no-tree-shake-icons
```

---

## 📡 API Endpoints

| Method | Endpoint                              | Description                        |
| ------ | ------------------------------------- | ---------------------------------- |
| POST   | `/api/auth/verify`                    | Role-based login handshake         |
| GET    | `/api/system/stats`                   | System-wide statistics             |
| GET    | `/api/system/alerts`                  | Active alerts for all buildings    |
| GET    | `/api/buildings/leaderboard`          | Ranked building list               |
| POST   | `/api/buildings`                      | Create a new building              |
| GET    | `/api/buildings/:id/stats`            | Building-specific stats & billing  |
| PUT    | `/api/buildings/:id/status`           | Toggle building Active/Suspended   |
| POST   | `/api/waste`                          | Log a waste entry                  |
| GET    | `/api/complaints/all`                 | All complaints (BMC Admin)         |
| GET    | `/api/complaints/building/:id`        | Complaints for a building          |
| GET    | `/api/complaints/cleaner/:id`         | Tasks assigned to a cleaner        |
| POST   | `/api/complaints`                     | Raise a new complaint              |
| PUT    | `/api/complaints/:id/assign`          | Assign complaint to a cleaner      |
| PUT    | `/api/complaints/:id/resolve`         | Mark complaint as resolved         |
| POST   | `/api/warnings`                       | Send warning to a building         |
| GET    | `/api/warnings/building/:id`          | Fetch warnings for a building      |
| PUT    | `/api/warnings/:id/read`              | Mark warning as read               |
| GET    | `/api/cleaners`                       | List all cleaners                  |
| GET    | `/api/cleaners/workload`              | Cleaner workload ranking           |
| POST   | `/api/cleaners`                       | Register a new cleaner             |
| GET    | `/api/settings`                       | Get pricing settings               |
| PUT    | `/api/settings`                       | Update pricing settings            |
| GET    | `/api/reports/csv`                    | Download CSV compliance report     |
| GET    | `/api/reports/pdf`                    | Download PDF compliance report     |

---

## 🗂️ Data Models

| Model            | Key Fields                                                     |
| ---------------- | -------------------------------------------------------------- |
| **Building**     | name, email, address, ward, assignedCleanerId, currentGreenScore, status |
| **WasteLog**     | buildingId, wetWeight, dryWeight, rejectWeight, cleanerId, date |
| **Complaint**    | buildingId, description, category, status, assignedCleanerId   |
| **Cleaner**      | name, email, phone, assignedWard, status                       |
| **Warning**      | buildingId, buildingName, alertType, message, additionalNote, status |
| **SystemSettings** | wetWastePrice, dryWastePrice, rejectWastePrice               |

---

## 👥 Team

Built as part of a Field Project by students exploring smart city waste management solutions.

---

## 📄 License

This project is for academic purposes.
