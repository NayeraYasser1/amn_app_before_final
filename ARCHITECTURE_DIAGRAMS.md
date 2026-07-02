# System Architecture & Data Flow Diagrams

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │         CompleteProfileScreen (UI)              │  │
│  │  ┌─────────────────────────────────────────┐   │  │
│  │  │ - Profile Picture Upload               │   │  │
│  │  │ - First/Last Name Input                │   │  │
│  │  │ - Car Model Dropdown                   │   │  │
│  │  │ - Plate Number Input                   │   │  │
│  │  │ - Car Color Dropdown                   │   │  │
│  │  └─────────────────────────────────────────┘   │  │
│  └──────────────────┬───────────────────────────┘  │  │
│                     │                              │  │
│  ┌──────────────────▼───────────────────────────┐  │  │
│  │        UserService (Business Logic)          │  │  │
│  │  ┌────────────────────────────────────────┐ │  │  │
│  │  │ - uploadProfilePicture()              │ │  │  │
│  │  │ - createUserProfile()                 │ │  │  │
│  │  │ - updateCarDetails()                  │ │  │  │
│  │  │ - getUserProfile()                    │ │  │  │
│  │  │ - userProfileStream()                 │ │  │  │
│  │  └────────────────────────────────────────┘ │  │  │
│  └──────────────┬────────────────────────┬──────┘  │  │
└─────────────────┼────────────────────────┼──────────┘  │
                  │                        │
        ┌─────────▼──────┐      ┌──────────▼───────┐
        │  Firebase Auth │      │  Firebase Cloud  │
        │   (User Login) │      │  Firestore (DB)  │
        │                │      │                  │
        │ - Authentication      │ - User Profiles  │
        │ - User Session │      │ - Car Details    │
        └────────────────┘      │ - Timestamps     │
                                └────────┬────────┘
                                         │
                                ┌────────▼────────┐
                                │  Firebase Cloud │
                                │  Storage        │
                                │                 │
                                │ - Profile Pics  │
                                └─────────────────┘
```

## Data Model Relationship Diagram

```
┌───────────────────────────────┐
│      UserProfile              │
├───────────────────────────────┤
│ + userId: String              │
│ + email: String               │
│ + firstName: String           │
│ + lastName: String            │
│ + profilePictureUrl: String   │
│ + carDetails: CarDetails ─────┐
│ + createdAt: DateTime         │
│ + updatedAt: DateTime         │
└───────────────────────────────┘
                                 │
                                 │ 1:1 Relationship
                                 │
                                 ▼
                    ┌───────────────────────────┐
                    │    CarDetails             │
                    ├───────────────────────────┤
                    │ + model: String           │
                    │ + plateNumber: String     │
                    │ + color: String           │
                    └───────────────────────────┘
```

## Firestore Data Structure

```
Firestore Database
│
└── users (Collection)
    │
    ├── user_id_1 (Document)
    │   ├── userId: "user_id_1"
    │   ├── email: "john@example.com"
    │   ├── firstName: "John"
    │   ├── lastName: "Doe"
    │   ├── profilePictureUrl: "https://..."
    │   ├── carDetails (Object)
    │   │   ├── model: "Toyota"
    │   │   ├── plateNumber: "ABC123"
    │   │   └── color: "Black"
    │   ├── createdAt: 2024-04-23T10:30:00Z
    │   └── updatedAt: 2024-04-23T10:30:00Z
    │
    ├── user_id_2 (Document)
    │   ├── userId: "user_id_2"
    │   ├── email: "jane@example.com"
    │   ├── firstName: "Jane"
    │   ├── lastName: "Smith"
    │   ├── profilePictureUrl: "https://..."
    │   ├── carDetails (Object)
    │   │   ├── model: "Honda"
    │   │   ├── plateNumber: "XYZ789"
    │   │   └── color: "White"
    │   ├── createdAt: 2024-04-23T11:00:00Z
    │   └── updatedAt: 2024-04-23T11:00:00Z
    │
    └── ... (more users)
```

## Firebase Storage Structure

```
Firebase Storage
│
└── profile_pictures (Folder)
    │
    ├── user_id_1 (Folder)
    │   ├── 1713873000000.jpg
    │   └── 1713873100000.jpg (replaced image)
    │
    ├── user_id_2 (Folder)
    │   └── 1713873050000.jpg
    │
    └── ... (more users)
```

## User Sign-Up to Profile Completion Flow

```
┌─────────────────────┐
│  User Opens App     │
└────────────┬────────┘
             │
             ▼
┌─────────────────────────┐
│  SignUpScreen           │
│  - Email               │
│  - Phone               │
│  - Password            │
│  - Driver License      │
│  - Car License         │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│  Phone Verification     │
│  Triggered via SMS      │
└────────────┬────────────┘
             │
             ▼
┌──────────────────────────┐
│  VerifyCodeScreen        │
│  - User Enters SMS Code  │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Firebase Auth           │
│  - Verify Credential     │
│  - Create User           │
└────────────┬─────────────┘
             │
             ▼
┌─────────────────────────────────┐
│  CompleteProfileScreen (NEW!)   │
│  - First Name                  │
│  - Last Name                   │
│  - Profile Picture (optional)  │
│  - Car Model (dropdown)        │
│  - Plate Number               │
│  - Car Color (dropdown)        │
└────────────┬────────────────────┘
             │
             ▼
┌──────────────────────────┐
│  UserService Operations  │
│  1. Upload Image (if)   │
│  2. Create Profile      │
└────────────┬─────────────┘
             │
             ▼
┌──────────────────────────┐
│  Firestore Write         │
│  + Storage Write (if)    │
└────────────┬─────────────┘
             │
             ▼
┌─────────────────────┐
│  Home Screen        │
│  Profile Complete   │
└─────────────────────┘
```

## Real-Time Profile Update Flow

```
┌──────────────────────────────────┐
│  Edit Profile Operation          │
│  (e.g., Change Car Color)        │
└────────────┬─────────────────────┘
             │
             ▼
┌──────────────────────────────────┐
│  UserService.updateCarDetailField│
│  - field: "color"               │
│  - value: "Red"                 │
└────────────┬─────────────────────┘
             │
             ▼
┌──────────────────────────────────┐
│  Firestore Update                │
│  - Find user document            │
│  - Update carDetails.color       │
│  - Update timestamp              │
└────────────┬─────────────────────┘
             │
             ▼
┌──────────────────────────────────┐
│  Listeners Notified              │
│  (userProfileStream)             │
└────────────┬─────────────────────┘
             │
             ▼
┌──────────────────────────────────┐
│  UI Updates Automatically        │
│  (StreamBuilder rebuilds)        │
└──────────────────────────────────┘
```

## Authentication & Authorization Flow

```
┌─────────────────────────────────────┐
│  User Makes Request (e.g., read)   │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Firebase Security Rules Check      │
│  request.auth.uid == userId?        │
└─────────────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
    ▼ YES             ▼ NO
┌──────────┐    ┌──────────────────┐
│  ALLOW   │    │  DENY            │
│          │    │  Permission Error│
│ Request  │    │                  │
│ proceeds │    │  Log as error    │
└──────────┘    └──────────────────┘
```

## User Isolation & Data Security

```
┌───────────────────────────────────────────────┐
│           Firestore Database                  │
│  ┌─────────────────────────────────────────┐ │
│  │ Security Rules:                         │ │
│  │ allow read: if request.auth.uid == uid │ │
│  │ allow write: if request.auth.uid == uid│ │
│  └─────────────────────────────────────────┘ │
│                                               │
│  ┌──────────────┐  ┌──────────────┐          │
│  │ User 1 Doc   │  │ User 2 Doc   │ Separate │
│  │ - ID: user_1 │  │ - ID: user_2 │ isolated │
│  │ - Name: John │  │ - Name: Jane │ documents│
│  │ - Car: Toyota│  │ - Car: Honda │          │
│  └──────────────┘  └──────────────┘          │
│                                               │
│  User 1 can READ/WRITE    User 2 cannot     │
│  only user_1 document       access user_1   │
│  (auth.uid = user_1)        data at all     │
└───────────────────────────────────────────────┘
```

## Image Upload & Storage Flow

```
┌─────────────────────────┐
│  User Selects Image     │
│  (Camera or Gallery)    │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Image Processing                   │
│  - Compress to quality 80           │
│  - Validate format (JPEG, PNG, etc) │
│  - Check size < 5MB                 │
└────────────┬────────────────────────┘
             │
             ▼
┌────────────────────────────────────────┐
│  Upload to Firebase Storage            │
│  Path: profile_pictures/{userId}/...   │
│  Metadata: {userId: ...}               │
└────────────┬─────────────────────────┘
             │
             ▼
┌────────────────────────────────────────┐
│  Get Download URL                      │
│  https://storage.googleapis.com/...    │
└────────────┬─────────────────────────┘
             │
             ▼
┌────────────────────────────────────────┐
│  Update Firestore Document             │
│  - profilePictureUrl: <URL>            │
│  - updatedAt: <timestamp>              │
└────────────┬─────────────────────────┘
             │
             ▼
┌────────────────────────────────────────┐
│  UI Updates with New Image             │
│  (Listeners notified)                  │
└────────────────────────────────────────┘
```

## Error Handling Flow

```
┌─────────────────────────┐
│  Operation Attempted    │
│  (e.g., uploadImage)    │
└────────────┬────────────┘
             │
             ▼
┌────────────────────────────┐
│  Try-Catch Block           │
└────────────┬───────────────┘
             │
      ┌──────┴──────┐
      │             │
      ▼ Success     ▼ Error
    ┌─────┐   ┌──────────────┐
    │ OK  │   │ Catch Block  │
    └─────┘   │              │
              ├─ Log Error   │
              ├─ Map Error   │
              │  Message     │
              ├─ Show        │
              │  SnackBar    │
              └──────────────┘
```

## Dependency Injection (Optional)

```
┌────────────────────────────────┐
│        Main Application        │
│                                │
│  final userService = UserService(
│    auth: FirebaseAuth.instance,
│    firestore: FirebaseFirestore.instance,
│    storage: FirebaseStorage.instance,
│  );
│                                │
│  ├─► CompleteProfileScreen    │
│  │   └─► UserService           │
│  │       └─► Firebase SDK      │
│  │                             │
│  └─► Other Screens             │
│      └─► UserService (shared)  │
│          └─► Firebase SDK      │
└────────────────────────────────┘
```

## Testing Pyramid

```
                    ▲
                   ╱ ╲
                  ╱ E2E ╲         (5%)
                 ╱────────╲
                ╱   Unit   ╲
              ╱─────────────╲     (50%)
             ╱   Integration ╲
            ╱──────────────────╲  (45%)
           ╱════════════════════╲
          
Tests to write:
- Unit: UserService methods
- Integration: Firebase operations
- E2E: Full signup flow
```

## Performance Metrics

```
Operation                  Time    Firestore   Storage
─────────────────────────  ────    ────────    ──────
Upload Profile Picture     1-3s    1 write     1 write
Create User Profile        100ms   1 write     0 writes
Retrieve Profile           50ms    1 read      0 reads
Listen to Profile Changes  ~10ms   Streaming   0 reads
Update Car Details         100ms   1 write     0 writes
```

## Scalability Considerations

```
Current Setup (Single Document per User)
│
├─► Scales well to 1-10 million users
│
├─► Each user:
│   └─► 1 document + optional image
│
└─► Total Operations/Day (per user):
    └─► ~10 reads
    └─► ~1-2 writes
    └─► ~0-1 image uploads
```

## Security Layers

```
Layer 1: Firebase Authentication
└─► Each request includes Firebase Auth token

Layer 2: Security Rules (Firestore)
└─► if request.auth.uid == userId ALLOW

Layer 3: Security Rules (Storage)
└─► if request.auth.uid == userId ALLOW

Layer 4: Application Logic
└─► UserService checks currentUser != null

Layer 5: Data Validation
└─► Form validation (client-side)
└─► Rules validation (server-side)
```
