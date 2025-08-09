# SnagSnapper Product Requirements Document (PRD)

## Executive Summary

SnagSnapper is an offline-first mobile application designed for construction site defect management. Built with Flutter for cross-platform deployment (iOS and Android), the app enables site managers and construction teams to efficiently document, track, and resolve site defects (snags) in environments with poor or no internet connectivity.

The app addresses the critical need for digital defect management in construction sites where traditional paper-based systems are inefficient and internet connectivity is unreliable. By providing a robust offline-first architecture with automatic synchronization, SnagSnapper ensures continuous productivity regardless of network conditions.

## Table of Contents

1. [Product Vision](#product-vision)
2. [Problem Statement](#problem-statement)
3. [Solution Overview](#solution-overview)
4. [User Personas](#user-personas)
5. [Core Features](#core-features)
6. [Technical Architecture](#technical-architecture)
7. [User Flows](#user-flows)
8. [Data Models](#data-models)
9. [Security & Privacy](#security--privacy)
10. [Performance Requirements](#performance-requirements)
11. [Success Metrics](#success-metrics)
12. [Release Strategy](#release-strategy)
13. [Future Enhancements](#future-enhancements)

## Product Vision

### Mission Statement
To revolutionize construction site defect management by providing a reliable, offline-capable mobile solution that streamlines documentation, assignment, and resolution of site issues, ultimately improving construction quality and project efficiency.

### Core Values
- **Reliability**: Works anywhere, anytime, with or without internet
- **Simplicity**: Intuitive interface requiring minimal training
- **Efficiency**: Reduces time spent on defect documentation by 80%
- **Accountability**: Clear ownership and tracking of issues
- **Cost-Effective**: Minimal infrastructure requirements

## Problem Statement

### Current Challenges in Construction Site Management

1. **Poor Connectivity**: Construction sites often lack reliable internet, making cloud-based solutions unusable
2. **Paper-Based Inefficiency**: Traditional paper forms are easily lost, damaged, or illegible
3. **Lack of Accountability**: No clear tracking of who is responsible for fixing defects
4. **Communication Gaps**: Information doesn't flow efficiently between site managers and workers
5. **Delayed Resolution**: Snags remain unresolved due to poor tracking and follow-up
6. **No Visual Documentation**: Paper forms can't effectively capture photographic evidence
7. **Reporting Difficulties**: Generating progress reports is time-consuming and error-prone

### Impact
- Project delays due to unresolved defects
- Increased costs from rework and inefficiencies
- Quality issues affecting client satisfaction
- Safety risks from unaddressed hazards

## Solution Overview

SnagSnapper addresses these challenges through:

### 1. Offline-First Architecture
- Complete functionality without internet connection
- Automatic synchronization when connectivity is restored
- Local data storage using SQLite
- Intelligent conflict resolution

### 2. Visual Documentation
- Capture up to 4 photos per snag
- Before/after photo comparison
- Image compression and optimization
- Markup tools for highlighting issues

### 3. Smart Assignment System
- Assign snags to specific workers
- Track status from creation to resolution
- Email notifications when online
- Clear accountability chain

### 4. Efficient Workflow
- Quick snag creation with minimal fields
- Batch operations for multiple snags
- Template support for common issues
- Voice-to-text for descriptions

### 5. Comprehensive Reporting
- PDF export with all snag details
- Progress tracking dashboards
- Site-wide statistics
- Custom report generation

## User Personas

### 1. Site Manager (Primary User)
**Name**: John Smith  
**Age**: 45  
**Role**: Construction Site Manager  
**Tech Level**: Moderate  

**Goals**:
- Document all site defects quickly
- Assign work to appropriate teams
- Track resolution progress
- Generate reports for clients

**Pain Points**:
- Spends hours on paperwork
- Difficult to track who fixed what
- Can't access data when offline
- Hard to share information with team

### 2. Site Worker (Secondary User)
**Name**: Maria Garcia  
**Age**: 32  
**Role**: Site Supervisor  
**Tech Level**: Basic  

**Goals**:
- View assigned snags easily
- Update snag status after completion
- Add photos of completed work
- Minimize time on documentation

**Pain Points**:
- Paper lists get damaged/lost
- Unclear instructions
- No way to prove work completion
- Communication delays

### 3. Project Director (Stakeholder)
**Name**: David Chen  
**Age**: 50  
**Role**: Project Director  
**Tech Level**: Advanced  

**Goals**:
- Monitor overall project quality
- View progress across multiple sites
- Generate client reports
- Ensure compliance

**Pain Points**:
- Lack of real-time visibility
- Inconsistent reporting formats
- Difficulty aggregating data
- No audit trail

## Core Features

### Phase 1: MVP (Completed)

#### 1. User Authentication & Profile Management
- **Google Sign-In**: One-tap authentication
- **Email/Password**: Traditional authentication with email verification
- **Profile Setup**: Name, company, phone, job title, location
- **Company Logo**: Upload and display across app
- **Digital Signature**: Capture and store for reports

#### 2. Site Management
- **Create Sites**: Name, location, company association
- **Site Images**: One image per site for identification
- **Picture Quality Settings**: Low/Medium/High for bandwidth control
- **Archive Sites**: Soft delete with restoration option
- **Share Sites**: 
  - Manual sharing with colleagues via email
  - Share codes for easy site joining (8-character codes)
  - Permission levels: Owner, Viewer

#### 3. Snag (Defect) Management
- **Create Snags**: 
  - Location within site
  - Title and detailed description
  - Priority levels (Low, Medium, High)
  - Up to 4 photos per snag
  - Due dates
- **Assignment System**:
  - Assign to registered users
  - Track assigned vs unassigned
  - Email notifications (when online)
- **Status Tracking**:
  - Open/Active status
  - Pending review (after fix)
  - Closed/Resolved
- **Fix Documentation**:
  - Fix description by assignee
  - Up to 4 "after" photos
  - Timestamp tracking

#### 4. Offline Functionality
- **Complete Offline Operation**: All features work without internet
- **Smart Sync Queue**: Prioritized sync (Snags → Sites → Profile)
- **Conflict Resolution**: Last-write-wins strategy
- **Visual Indicators**: Sync status icons
- **Retry Mechanism**: Exponential backoff with manual retry option

#### 5. Image Management
- **Smart Compression**: Based on quality settings
- **Local Caching**: Instant image display
- **Firebase Storage**: Cloud backup when online
- **ETag Validation**: Efficient cache updates
- **Orphan Cleanup**: Automatic removal of unused images

### Phase 2: Enhanced Features (Planned)

#### 1. Advanced Reporting
- **PDF Generation**: Professional reports with branding
- **Excel Export**: Data analysis capabilities
- **Custom Templates**: Reusable report formats
- **Scheduled Reports**: Automatic generation

#### 2. Team Collaboration
- **Comments System**: Discussion threads on snags
- **Activity Feed**: Real-time updates
- **@Mentions**: Direct notifications
- **Read Receipts**: Tracking who viewed what

#### 3. Analytics Dashboard
- **Snag Statistics**: Creation/resolution rates
- **Performance Metrics**: Team productivity
- **Trend Analysis**: Issue patterns
- **Predictive Insights**: AI-powered recommendations

## Technical Architecture

### Technology Stack

#### Frontend
- **Framework**: Flutter 3.x
- **State Management**: Provider pattern
- **Local Database**: SQLite via sqflite
- **Image Handling**: image_picker, image package
- **Navigation**: Named routes with arguments

#### Backend
- **Authentication**: Firebase Auth (Google + Email/Password)
- **Database**: Cloud Firestore
- **File Storage**: Firebase Storage
- **Analytics**: Firebase Analytics
- **Crash Reporting**: Firebase Crashlytics

#### Architecture Patterns
- **MVVM**: Model-View-ViewModel separation
- **Repository Pattern**: Data access abstraction
- **Singleton Services**: Shared service instances
- **Offline-First**: Local-first with cloud sync

### Data Flow Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Flutter App   │────▶│ Firebase Auth    │────▶│ Google OAuth    │
│  (Offline-First)│     └──────────────────┘     └─────────────────┘
└────────┬────────┘              │
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│  Local SQLite   │     │    Firestore     │
│   Database      │◀───▶│    Database      │
└─────────────────┘ Sync └──────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐     ┌──────────────────┐
│  Local Image    │     │ Firebase Storage │
│     Cache       │◀───▶│   (Images)       │
└─────────────────┘ Sync └──────────────────┘
```

### Offline Sync Strategy

1. **Entity Priority**: Snags (highest) → Sites → Profile (lowest)
2. **Operation Order**: Creates → Updates → Deletes
3. **Retry Strategy**: 
   - Immediate retry
   - 2-second delay
   - 5-second delay
   - Move to manual queue
4. **Conflict Resolution**: Last-write-wins with timestamp comparison

## User Flows

### 1. First-Time User Flow
```
Start → Google/Email Sign-in → Email Verification (if email) 
→ Profile Setup (Name, Company, etc.) → Main Menu
```

### 2. Site Creation Flow
```
Main Menu → My Sites → Create Site → Enter Details 
→ Add Photo (optional) → Save → View Site
```

### 3. Snag Creation Flow
```
Site View → Create Snag → Fill Details → Take Photos 
→ Assign Worker (optional) → Set Due Date → Save
```

### 4. Snag Resolution Flow
```
Assigned Snags → Select Snag → Add Fix Description 
→ Take After Photos → Submit → Owner Reviews → Close Snag
```

### 5. Site Sharing Flow
```
Site Settings → Share Site → Choose Method:
- Manual: Select Colleagues → Grant Access
- Code: Share 8-char Code → Recipient Enters Code → Auto-Access
```

## Data Models

### User Profile
```json
{
  "name": "string (required, 2-100 chars)",
  "email": "string (required, validated)",
  "companyName": "string (required, 2-200 chars)",
  "phone": "string (required, 7-15 digits)",
  "jobTitle": "string (required, 1-100 chars)",
  "postcodeArea": "string (optional, 1-20 chars)",
  "dateFormat": "string (dd-MM-yyyy | MM-dd-yyyy | yyyy-MM-dd)",
  "image": "string (relative path)",
  "signature": "string (relative path)",
  "listOfColleagues": ["email1", "email2"],
  "lastUpdated": "timestamp"
}
```

### Site
```json
{
  "uID": "string (UUID)",
  "name": "string (required, 2-100 chars)",
  "companyName": "string (snapshot from profile)",
  "location": "string (required, 2-500 chars)",
  "date": "timestamp (creation)",
  "ownerEmail": "string",
  "ownerName": "string",
  "pictureQuality": "number (0-2)",
  "archive": "boolean",
  "image": "string (optional path)",
  "sharedWith": {
    "email1": "OWNER",
    "email2": "VIEW"
  },
  "shareCode": "string (8 chars, unique)"
}
```

### Snag
```json
{
  "uID": "string (UUID)",
  "siteUID": "string (parent site)",
  "location": "string (within site, required)",
  "title": "string (required, 2-200 chars)",
  "description": "string (required, 2-1000 chars)",
  "priority": "number (0=low, 1=medium, 2=high)",
  "creatorEmail": "string",
  "ownerEmail": "string (site owner)",
  "assignedEmail": "string (optional)",
  "assignedName": "string (optional)",
  "dueDate": "timestamp (optional)",
  "creationDate": "timestamp",
  "snagStatus": "boolean (true=open)",
  "snagConfirmedStatus": "boolean",
  "imageMain1": "string (path)",
  "image2-4": "string (paths)",
  "snagFixDescription": "string (2-1000 chars)",
  "snagFixMainImage": "string (path)",
  "snagFixImage1-3": "string (paths)"
}
```

## Security & Privacy

### Authentication Security
- Firebase Auth integration
- Email verification required
- Secure token management
- Automatic session refresh
- Biometric authentication (planned)

### Data Security
- **At Rest**: SQLite encryption
- **In Transit**: HTTPS/TLS
- **Firebase Rules**: Role-based access control
- **Image Security**: User-isolated storage paths

### Privacy Features
- Complete data removal on logout
- No cross-user data access
- GDPR compliance ready
- Audit trail for all actions
- Data retention policies

### Firebase Security Rules
- Email verification required
- Profile immutability (email can't change)
- Site access based on sharedWith map
- Snag permissions inherited from sites
- Rate limiting (5-second cooldown)

## Performance Requirements

### App Performance
- **Startup Time**: < 3 seconds
- **Image Processing**: < 2 seconds
- **Screen Navigation**: < 500ms
- **Database Queries**: < 100ms
- **Sync Operations**: Background, non-blocking

### Resource Efficiency
- **Memory Usage**: < 150MB active
- **Storage**: ~10MB per active user
- **Battery**: < 5% drain per hour active use
- **Network**: Minimal data usage (compressed images)

### Scalability
- Support 1000+ snags per site
- Handle 50+ sites per user
- 100 colleagues per user
- Batch operations up to 500 items

## Success Metrics

### User Adoption
- **Target**: 10,000 active users in Year 1
- **Daily Active Users**: 60% of registered
- **Session Duration**: Average 15 minutes
- **Feature Adoption**: 80% use photo feature

### Business Impact
- **Time Saved**: 80% reduction in documentation time
- **Snag Resolution**: 50% faster closure rate
- **Report Generation**: From hours to minutes
- **Cost Savings**: $500/month per site

### Technical Metrics
- **Crash Rate**: < 0.1%
- **Sync Success**: > 99.9%
- **Offline Usage**: 40% of sessions
- **Cache Hit Rate**: > 90%

## Release Strategy

### Phase 1: MVP (Current)
- Core authentication and profiles
- Basic site and snag management
- Offline functionality
- Image handling
- Share codes

### Phase 2: Enhanced Collaboration
- Comments and discussions
- Advanced reporting
- Team analytics
- Push notifications

### Phase 3: Enterprise Features
- Multi-company support
- API access
- Custom workflows
- Integration capabilities

### Phase 4: AI & Automation
- Snag categorization
- Predictive analytics
- Auto-assignment
- Voice commands

## Future Enhancements

### Short Term (3-6 months)
1. **Biometric Authentication**: FaceID/TouchID support
2. **Dark Mode**: Full theme support
3. **Tablet Optimization**: iPad/Android tablet layouts
4. **Bulk Operations**: Multi-select actions
5. **Templates**: Reusable snag templates

### Medium Term (6-12 months)
1. **Web Dashboard**: Browser-based management
2. **API Integration**: Third-party connections
3. **Advanced Search**: Full-text search with filters
4. **Workflow Automation**: Custom status flows
5. **Multi-language**: Internationalization

### Long Term (12+ months)
1. **AI Features**: 
   - Auto-categorization
   - Similar snag detection
   - Resolution suggestions
2. **AR Integration**: Augmented reality for snag location
3. **IoT Sensors**: Automatic issue detection
4. **Blockchain**: Immutable audit trail
5. **Predictive Maintenance**: AI-driven insights

## Conclusion

SnagSnapper represents a significant advancement in construction site management technology. By focusing on offline-first functionality, simple user experience, and robust synchronization, it addresses the real-world challenges faced by construction professionals daily.

The app's success will be measured not just by user adoption, but by the tangible improvements in project quality, efficiency, and communication it delivers. With a clear roadmap for enhancement and a strong technical foundation, SnagSnapper is positioned to become the industry standard for digital defect management in construction.

---

*Document Version: 1.0*  
*Last Updated: January 2025*  
*Status: In Development*