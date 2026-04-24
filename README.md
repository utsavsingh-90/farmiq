# FarmIQ — Crop Recommendation System

FarmIQ is a comprehensive civic-tech platform designed to empower farmers with data-driven crop recommendations and provide administrators with strategic oversight of regional agricultural health.

## 🚀 Quick Links
- **Local Application:** [http://127.0.0.1:5001/](http://127.0.0.1:5001/)
- **Stats Dashboard:** [Stats Dashboard (Local)](file:///Users/utsavsingh/Downloads/stats_dashboard.html)

---

## 🛠️ Technology Stack
- **Frontend:**
  - **HTML5/CSS3:** Custom premium design system with dark/light mode support.
  - **JavaScript (Vanilla):** Single Page Application (SPA) architecture with dynamic tab switching and real-time API integration.
- **Backend:**
  - **Flask (Python):** RESTful API handling data persistence and business logic.
  - **MySQL:** Relational database for storing farmer profiles, land parcels, soil test history, and recommendation records.
- **AI Integration:**
  - **Anthropic (Claude):** Integrated via a secure backend proxy for future-ready AI insights (currently supports DB-driven recommendation logic).

---

## 🏗️ Core Architecture

### 1. Farmer Portal
- **Registration:** Capture farmer demographics and regional data.
- **Land Management:** Map specific land parcels with GPS coordinates and irrigation types.
- **Soil Analysis:** Record periodic soil test results (N, P, K, pH, Organic Matter).
- **Smart Recommendations:** A DB-driven engine that matches soil health against crop requirements and regional climate data.

### 2. Admin Dashboard
- **Strategic Overview:** Real-time KPIs for total registrations and activities.
- **Resource Management:** Detailed views of all farmers, land parcels, and soil test histories across the ecosystem.
- **Activity Feed:** Monitor latest recommendations generated for farmers.

### 3. SQL Query Demonstration
A dedicated educational section showing complex SQL operations on the live dataset:
- **JOINs:** Relational matching across 4+ tables.
- **Aggregations:** Average profit analysis using `GROUP BY`.
- **Subqueries:** Identifying high-performing land parcels.
- **Stored Procedures:** Encapsulated logic for suitablity matching.

### 4. Stats Dashboard
- An external high-fidelity dashboard linked directly from the navigation bar, providing deep visual insights into agricultural trends.

---

## ⚙️ Project Structure
- `app.py`: Main Flask server with API endpoints.
- `templates/index4.html`: Unified frontend interface.
- `crop_recommendation_fixed.sql`: Database schema and seed data.
- `/Users/utsavsingh/Downloads/stats_dashboard.html`: External statistics visualization.

---

## 🏃 How to Run
1. Ensure MySQL is running with the `crop_recommendation_db` database.
2. Start the Flask server:
   ```bash
   python3 app.py
   ```
3. Open the browser at `http://127.0.0.1:5001/`.
