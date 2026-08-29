# 🏥 CareQueue — Clinic Token Management System

## 🚀 Setup (3 Steps)

### 1. Database (XAMPP)
```
XAMPP → Apache + MySQL → Start
phpMyAdmin → http://localhost/phpmyadmin
New Database: carequeue
Import: database/carequeue.sql
```

### 2. Backend (Node.js)
```bash
cd backend
npm install
node server.js
# ✅ http://localhost:3000
```

### 3. Flutter App
```bash
cd mobile
flutter pub get
flutter run
```

## 🔑 Demo Credentials
- **Doctor:** CLN-2024-001 / doctor123
- **Patient:** arun@gmail.com / patient123

## 📱 Real Device Setup
`mobile/lib/services/api_service.dart` → baseUrl மாத்துங்கள்:
```dart
// CMD: ipconfig → IPv4 Address
static const String baseUrl = 'http://192.168.X.X:3000/api';
```
"# carequeue_project" 
