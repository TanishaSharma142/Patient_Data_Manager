# Quick Start Guide - IVF Patient Management System

## 🚀 Get Running in 5 Minutes

### Option A: Docker (Easiest)

```bash
cd IVF
docker-compose up --build
```

**Done!** API is at `http://localhost:3000`

Test: 
```bash
curl http://localhost:3000/health
# Should return: {"status":"ok","timestamp":"2024-..."}
```

### Option B: Manual Setup

#### 1. Backend Setup (2 minutes)

```bash
cd backend

# Install dependencies
npm install

# Setup database (assumes PostgreSQL running locally)
cp .env.example .env
# Edit .env and set DATABASE_URL

# Initialize database
npm run prisma:generate
npm run prisma:migrate
npm run prisma:seed

# Start server
npm run dev
```

#### 2. Flutter Setup (1 minute)

```bash
cd ../flutter_app

# Get dependencies
flutter pub get

# Run web app
flutter run -d chrome
```

---

## 🔓 Test Login

Use any of these credentials:

**Owner (Full Access):**
```
Username: rakesh
Password: owner123
```

**Accountant (Financial Only):**
```
Username: accountant
Password: accountant123
```

**Secretary (Non-Financial Only):**
```
Username: secretary
Password: secretary123
```

---

## 🎯 First Steps

1. **Add a patient**: Click "+" button (owners/secretaries only)
2. **View details**: Click any patient card
3. **Edit data**: Click edit button (role-permitting)
4. **View audit**: Click settings → Activity Log
5. **Panic wipe** (Owner only): Settings → Alarm Erase

---

## 📋 Common Commands

### Backend

```bash
# Development with auto-reload
npm run dev

# Production build
npm run build
npm start

# Database operations
npm run prisma:migrate
npm run prisma:seed
npm run prisma:studio  # Visual DB editor
```

### Flutter

```bash
# Run web
flutter run -d chrome

# Run mobile
flutter run

# Build for release
flutter build web --release
flutter build apk --release
flutter build ios --release
```

---

## 🔧 Environment Setup

### Backend (.env)

Required variables:
```env
DATABASE_URL=postgresql://user:password@localhost:5432/ivf_db
JWT_SECRET=your-secret-key
ENCRYPTION_KEY=5a44b91551d2d83c976312b1c8ee5b5a04eca4b6061c5da664c8f28c64fa18db
```

Optional (for email):
```env
BACKUP_EMAIL=admin@example.com
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASS=your_sendgrid_key
```

### Flutter

Update API URL in `lib/services/api_service.dart`:
```dart
static const String _baseUrl = 'http://localhost:3000/api';
```

For Android emulator:
```dart
static const String _baseUrl = 'http://10.0.2.2:3000/api';
```

---

## ✅ Verification Checklist

- [ ] Backend running at http://localhost:3000
- [ ] Health check passing: `curl http://localhost:3000/health`
- [ ] Flutter app running
- [ ] Can login with test credentials
- [ ] Can see patients list
- [ ] Can create/edit/delete patients (role-depending)

---

## 🆘 Troubleshooting

**"Cannot connect to database"**
```bash
# Check PostgreSQL is running
# Update DATABASE_URL in .env
# Run: npm run prisma:migrate
```

**"Token expired" in Flutter**
- App automatically refreshes tokens
- If persists, clear app data and re-login

**"Permission denied" errors**
- Check user role matches required permissions
- Owner has full access to all operations

**"Encryption key must be 64 hex characters"**
```bash
# Generate new key:
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

---

## 📚 Full Documentation

- **Detailed Setup**: See [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md)
- **Architecture**: See [ARCHITECTURE.md](ARCHITECTURE.md)
- **Project Summary**: See [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)
- **Main README**: See [README.md](README.md)

---

## 🎉 You're Ready!

The system is fully functional and production-ready. 

**Start by:**
1. Logging in with test credentials
2. Adding a few test patients
3. Trying different user roles
4. Exploring the audit log
5. (Owner only) Testing panic wipe

---

**Need Help?** Check [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for detailed troubleshooting.
