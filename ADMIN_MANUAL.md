# TRIminder Admin Dashboard - Administrator Manual

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [User Roles & Permissions](#user-roles--permissions)
4. [Dashboard Overview](#dashboard-overview)
5. [Student Management](#student-management)
6. [Admin Management](#admin-management)
7. [Department Management](#department-management)
8. [Analytics](#analytics)
9. [Troubleshooting](#troubleshooting)

---

## Introduction

TRIminder Admin Dashboard is a web-based management system designed to monitor and manage student screen time data from the TRIminder mobile application. The dashboard provides comprehensive analytics, student management, and administrative controls for educational institutions.

### Key Features

- **Real-time Analytics** - Monitor student screen time patterns and trends
- **Role-Based Access Control** - Super Admin and Department Admin roles with different access levels
- **Student Monitoring** - View individual student profiles, usage history, and achievements
- **Department Management** - Organize students and admins by department
- **Data Visualization** - Charts and graphs for usage trends, XP distribution, and demographics
- **Report Generation** - Export student data to PDF format

---

## Getting Started

### Accessing the Dashboard

1. Open your web browser and navigate to the TRIminder Admin Dashboard URL
2. You will be presented with the login screen

### Logging In

1. Enter your **Username** in the first field
2. Enter your **Password** in the second field
3. Click the **Sign In** button
4. Upon successful authentication, you will be redirected to the Dashboard

> **Note:** If you see an error message, verify your credentials are correct. Contact your Super Admin if you need password assistance.

### Navigation

The dashboard uses a sidebar navigation system:

| Menu Item | Description | Access Level |
|-----------|-------------|--------------|
| Dashboard | Overview and key metrics | All Admins |
| Students | Student list and management | All Admins |
| Admins | Admin account management | Super Admin Only |
| Departments | Department management | Super Admin Only |
| Analytics | Detailed analytics and reports | All Admins |

---

## User Roles & Permissions

### Super Admin

Super Admins have full access to all system features:

- View all students across all departments
- Manage admin accounts (create, edit, delete)
- Manage departments (create, edit, delete)
- Access global analytics and department comparisons
- Filter data by any department

### Department Admin (Sub Admin)

Department Admins have limited access based on their assigned department:

- View students only within their assigned department
- Access department-specific analytics
- Cannot manage admin accounts
- Cannot manage departments
- Cannot view data from other departments

---

## Dashboard Overview

The Dashboard provides a quick overview of key metrics and trends.

### Statistics Cards

The top section displays four key statistics:

1. **Total Students** - Total number of registered students (filtered by department for Sub Admins)
2. **Avg Daily Screen Time** - Average daily screen time across all students
3. **Top Dept (Screen Time)** / **Total XP** - For Super Admins: department with highest screen time; For Sub Admins: total XP earned
4. **Top Year Level (Screen Time)** - Year level with the highest average screen time

### Usage Trend Chart

Displays screen time trends over time with three view options:

- **Daily** - Shows daily screen time for the past 7 days
- **Weekly** - Shows weekly aggregated data
- **Monthly** - Shows monthly aggregated data

### Top 10 Students

A leaderboard showing students ranked by screen time:

- Click the **sort toggle** button to switch between highest-first and lowest-first
- Use the time range buttons (Daily, Weekly, Monthly) to change the period
- Click on any student to view their detailed profile
- Rankings are indicated with gold, silver, and bronze badges for top 3

### Department-Specific Charts (Super Admin)

Super Admins see additional charts:

- **Avg Screen Time by Dept** - Bar chart comparing average screen time across departments
- **Department Comparison Table** - Detailed breakdown showing:
  - Department name
  - Total students
  - Average screen time
  - Total XP

### Distribution Charts

- **Year Level Distribution** - Breakdown of students by academic year (1st-4th Year)
- **Gender Distribution** - Semi-donut chart showing male/female/other distribution with average screen time per gender

### Department Filter (Super Admin)

Super Admins can filter all dashboard data by department using the dropdown in the header:

1. Click the **All Departments** dropdown
2. Select a specific department to filter
3. Select **All Departments** to view global data

---

## Student Management

### Viewing Students

Navigate to **Students** from the sidebar to access the student list.

#### Student Table Columns

| Column | Description |
|--------|-------------|
| Student ID | Unique identifier |
| Name | Full name with avatar |
| Email | Student email address |
| Year Level | Academic year (1st-4th) |
| Gender | Male/Female/Not Specified |
| Department | Assigned department |
| AVG Daily Screentime | Average daily screen time |
| Badges | Number of earned badges |
| Last Active | Last recorded activity date |
| Actions | View Details button |

### Searching Students

Use the search bar to find students by:
- Name (first or last)
- Email address
- Student ID

### Filtering Students

1. Click the **Filters** button to expand filter options
2. Available filters:
   - **Year Level** - Filter by academic year
   - **Department** - Filter by department (available to all, but Super Admins can filter across all departments)
   - **Gender** - Filter by gender
3. Active filters appear as chips below the search bar
4. Click **Clear all** to remove all filters

### Sorting Students

Click any sortable column header to sort:
- Click once for ascending order
- Click again for descending order
- A sort indicator shows the current sort direction

### Pagination

- Navigate between pages using the pagination controls
- Shows 10 students per page
- Displays current range (e.g., "Showing 1 to 10 of 150 students")

### Printing Student Reports

1. Apply desired filters and search criteria
2. Click the **Print PDF** button
3. A print preview opens in a new window
4. The report includes:
   - TRIminder header with logos
   - Generation timestamp
   - Total student count
   - Complete filtered student list
5. Use your browser's print function to save as PDF or print

### Viewing Student Details

Click **View Details** on any student row to access their profile page.

#### Student Profile Sections

**Header Section**
- Profile photo or initials avatar
- Full name
- Email address
- User tag

**Statistics Cards**
- **Level** - Calculated from XP (Level = XP/100 + 1)
- **AVG Screentime** - Average daily screen time
- **Badges Earned** - Total achievements
- **Student ID** - Unique identifier

**Usage History Chart**
- Line chart showing daily screen time for the last 30 days
- Hover over data points to see exact values

**Achievements & Badges**
- Grid display of earned badges
- Each badge shows:
  - Badge icon
  - Badge name
  - Description
  - Date earned

**Student Information**
- User Tag
- Year Level
- Gender
- Date of Birth
- Member Since (registration date)

Click **← Back to Students** to return to the student list.

---

## Admin Management

> **Note:** This section is only accessible to Super Admins.

Navigate to **Admins** from the sidebar.

### Admin Table Columns

| Column | Description |
|--------|-------------|
| Name | Admin's full name |
| Username | Login username |
| Department | Assigned department (N/A for Super Admins) |
| Status | Active or Inactive |
| Actions | Edit and Delete buttons |

### Creating a New Admin

1. Click **+ Add Admin** button
2. Fill in the form:
   - **Name** - Full name (required)
   - **Username** - Login username (required, must be unique)
   - **Password** - Login password (required)
   - **Department** - Select department or "None (Super Admin)" for super admin access
   - **Active** - Check to enable the account
3. Click **Save** to create the admin

### Editing an Admin

1. Click **Edit** on the admin row
2. Modify the fields as needed
3. Leave **Password** empty to keep the current password
4. Click **Save** to apply changes

### Deleting an Admin

1. Click **Delete** on the admin row
2. Confirm the deletion in the popup dialog
3. The admin will be removed from the system

> **Important:** The default admin account (`admin`) cannot be modified or deleted. The currently logged-in admin is also hidden from the list to prevent self-deletion.

### Admin Role Assignment

- **Super Admin**: Leave department as "None (Super Admin)"
- **Department Admin**: Select a specific department

---

## Department Management

> **Note:** This section is only accessible to Super Admins.

Navigate to **Departments** from the sidebar.

### Creating a Department

1. Click **+ Add Department**
2. Enter the **Name** of the department
3. Click **Save**

### Editing a Department

1. Click **Edit** on the department row
2. Modify the department name
3. Click **Save**

### Deleting a Department

1. Click **Delete** on the department row
2. Confirm the deletion

> **Warning:** Deleting a department may affect students and admins assigned to it. Reassign users before deletion.

---

## Analytics

Navigate to **Analytics** from the sidebar for detailed insights.

### Statistics Overview

Four key metrics displayed at the top:

1. **Total Students** - Total registered students
2. **Avg Daily Screen Time** - Average across all students
3. **Total XP** - Combined XP of all students
4. **Total Badges** - Total badges earned across all students

### Charts and Visualizations

**Weekly Usage Trend**
- Line chart showing screen time over the past 7 days
- Hover for exact values

**XP Distribution**
- Bar chart showing how XP is distributed across students

**Year Level Distribution**
- Bar chart showing student count by academic year

**Gender Distribution**
- Bar chart showing male/female/other breakdown

### Top 10 Students Leaderboard

- Ranked list of top performers by screen time
- Gold, silver, bronze indicators for top 3

### Department Comparison (Super Admin)

Table showing for each department:
- Number of students
- Average screen time
- Total XP earned

### Filtering Analytics

Super Admins can filter all analytics by department using the dropdown selector.

---

## Troubleshooting

### Login Issues

**Problem:** Cannot log in with credentials
- Verify username and password are correct
- Check if Caps Lock is enabled
- Contact Super Admin to verify account status is "Active"

**Problem:** Session expired
- Refresh the page and log in again
- Clear browser cookies if issues persist

### Data Not Loading

**Problem:** Dashboard shows loading spinner indefinitely
- Check internet connection
- Refresh the page
- Clear browser cache
- Contact system administrator if problem persists

**Problem:** No students appear in the list
- Verify you have the correct department filter selected
- Department Admins can only see their assigned department
- Check if filters are applied and try clearing them

### Export/Print Issues

**Problem:** PDF print preview doesn't open
- Check if pop-ups are blocked in your browser
- Allow pop-ups for the dashboard URL
- Try a different browser

### Access Denied

**Problem:** Cannot access Admins or Departments page
- Only Super Admins can access these pages
- Verify your role with your system administrator

### Browser Compatibility

For best experience, use:
- Google Chrome (recommended)
- Mozilla Firefox
- Microsoft Edge
- Safari

Ensure your browser is updated to the latest version.

---

## Support

For technical issues or questions not covered in this manual, contact:

- Your institution's IT department
- TRIminder system administrator

---

*TRIminder Admin Dashboard - EVSU Screen Time Management System*

*Manual Version: 1.0*  
*Last Updated: November 2024*
