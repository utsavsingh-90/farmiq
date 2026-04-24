from flask import Flask, render_template, request, jsonify, send_from_directory
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import traceback
import os
import requests as _requests

app = Flask(__name__)
CORS(app)

# ─────────────────────────────────────────────
# DB CONFIG
# ─────────────────────────────────────────────
DB_CONFIG = dict(
    host=os.environ.get("DB_HOST", "127.0.0.1"),
    user=os.environ.get("DB_USER", "root"),
    password=os.environ.get("DB_PASSWORD", "utsavs1@@"),
    database=os.environ.get("DB_NAME", "crop_recommendation_db")
)

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")

def get_db():
    return mysql.connector.connect(**DB_CONFIG)

# ─────────────────────────────────────────────
# SERVE FRONTEND
# ─────────────────────────────────────────────
@app.route('/')
def home():
    return render_template('index4.html')

@app.route('/stats-dashboard')
def stats_dashboard():
    return send_from_directory('/Users/utsavsingh/Downloads', 'stats_dashboard.html')


# ════════════════════════════════════════════
#  FARMER
# ════════════════════════════════════════════

@app.route('/api/farmers', methods=['GET'])
def get_farmers():
    try:
        db = get_db()
        cur = db.cursor(dictionary=True)
        # LEFT JOIN Region on Farmer.region_id — every farmer has region even before adding land
        cur.execute("""
            SELECT f.farmer_id AS id, f.name, f.contact_number AS contact,
                   f.location, f.farm_size AS size,
                   r.region_id AS region_id,
                   r.region_name AS region,
                   (SELECT COUNT(*) FROM Land_Parcel lp WHERE lp.farmer_id = f.farmer_id) AS parcels
            FROM Farmer f
            LEFT JOIN Region r ON f.region_id = r.region_id
            ORDER BY f.farmer_id
        """)
        rows = cur.fetchall()
        db.close()
        return jsonify(rows)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/farmers', methods=['POST'])
def register_farmer():
    try:
        data = request.get_json()
        name     = data['name'].strip()
        contact  = data['contact'].strip()
        size     = float(data['size'])
        location = data['location'].strip()
        region   = data['region'].strip()

        db = get_db()
        cur = db.cursor()

        # get region_id
        cur.execute("SELECT region_id FROM Region WHERE region_name = %s", (region,))
        row = cur.fetchone()
        if not row:
            return jsonify({'error': f'Region "{region}" not found in DB'}), 400
        region_id = row[0]

        # insert farmer with region_id stored directly on the Farmer row
        cur.execute(
            "INSERT INTO Farmer (name, contact_number, location, farm_size, region_id) VALUES (%s,%s,%s,%s,%s)",
            (name, contact, location, size, region_id)
        )
        farmer_id = cur.lastrowid
        db.commit()
        db.close()
        return jsonify({'success': True, 'farmer_id': farmer_id, 'region_id': region_id})
    except Error as e:
        if e.errno == 1062:
            return jsonify({'error': 'Contact number already registered.'}), 409
        return jsonify({'error': str(e)}), 500


# ════════════════════════════════════════════
#  LAND PARCEL
# ════════════════════════════════════════════

@app.route('/api/lands', methods=['GET'])
def get_lands():
    try:
        db = get_db()
        cur = db.cursor(dictionary=True)
        cur.execute("""
            SELECT lp.land_id AS id, lp.latitude AS lat, lp.longitude AS lon,
                   lp.area, lp.irrigation_type AS irrigation,
                   f.farmer_id AS farmer_id, f.name AS farmer,
                   r.region_name AS region
            FROM Land_Parcel lp
            JOIN Farmer f ON lp.farmer_id = f.farmer_id
            JOIN Region  r ON lp.region_id  = r.region_id
            ORDER BY lp.land_id
        """)
        rows = cur.fetchall()
        db.close()
        return jsonify(rows)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/lands', methods=['POST'])
def add_land():
    try:
        data = request.get_json()
        farmer_id  = int(data['farmer_id'])
        region_id  = int(data['region_id'])
        lat        = float(data['lat'])
        lon        = float(data['lon'])
        area       = float(data['area'])
        irrigation = data['irrigation']

        db = get_db()
        cur = db.cursor()
        cur.execute(
            "INSERT INTO Land_Parcel (latitude,longitude,area,irrigation_type,farmer_id,region_id) "
            "VALUES (%s,%s,%s,%s,%s,%s)",
            (lat, lon, area, irrigation, farmer_id, region_id)
        )
        land_id = cur.lastrowid
        db.commit()
        db.close()
        return jsonify({'success': True, 'land_id': land_id})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ════════════════════════════════════════════
#  SOIL TEST
# ════════════════════════════════════════════

@app.route('/api/soils', methods=['GET'])
def get_soils():
    try:
        db = get_db()
        cur = db.cursor(dictionary=True)
        cur.execute("""
            SELECT st.land_id AS land_id, st.test_date AS date,
                   st.nitrogen_level AS n, st.phosphorus_level AS p,
                   st.potassium_level AS k, st.pH AS ph,
                   st.organic_matter AS om,
                   f.name AS farmer
            FROM Soil_Test st
            JOIN Land_Parcel lp ON st.land_id = lp.land_id
            JOIN Farmer f       ON lp.farmer_id = f.farmer_id
            ORDER BY st.land_id, st.test_date DESC
        """)
        rows = cur.fetchall()
        for r in rows:
            r['date'] = str(r['date'])
        db.close()
        return jsonify(rows)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/soils', methods=['POST'])
def save_soil():
    try:
        data = request.get_json()
        land_id = int(data['land_id'])
        date    = data['date']
        n  = float(data['n'])
        p  = float(data['p'])
        k  = float(data['k'])
        ph = float(data['ph'])
        om = float(data['om'])

        db = get_db()
        cur = db.cursor()
        cur.execute(
            "INSERT INTO Soil_Test (land_id,test_date,nitrogen_level,phosphorus_level,"
            "potassium_level,pH,organic_matter) VALUES (%s,%s,%s,%s,%s,%s,%s)"
            " ON DUPLICATE KEY UPDATE nitrogen_level=%s,phosphorus_level=%s,"
            "potassium_level=%s,pH=%s,organic_matter=%s",
            (land_id, date, n, p, k, ph, om, n, p, k, ph, om)
        )
        db.commit()
        db.close()
        return jsonify({'success': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ════════════════════════════════════════════
#  RECOMMENDATION
# ════════════════════════════════════════════

@app.route('/api/recommendations', methods=['GET'])
def get_recommendations():
    try:
        db = get_db()
        cur = db.cursor(dictionary=True)
        cur.execute("""
            SELECT r.recommendation_id AS id, r.land_id AS land_id,
                   f.name AS farmer, c.crop_name AS crop, c.crop_type AS type,
                   r.predicted_yield AS yield_val,
                   r.expected_profit AS profit,
                   r.sustainability_score AS score,
                   r.recommendation_date AS date
            FROM Recommendation r
            JOIN Land_Parcel lp ON r.land_id = lp.land_id
            JOIN Farmer f       ON lp.farmer_id = f.farmer_id
            JOIN Crop c         ON r.crop_id = c.crop_id
            ORDER BY r.recommendation_date DESC
        """)
        rows = cur.fetchall()
        for r in rows:
            r['date'] = str(r['date'])
            r['profit'] = float(r['profit']) if r['profit'] else 0
        db.close()
        return jsonify(rows)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/recommendations', methods=['POST'])
def save_recommendation():
    try:
        data = request.get_json()
        land_id       = int(data['land_id'])
        crop_name     = data['crop_name'].strip()
        pred_yield    = float(data['predicted_yield'])
        sust_score    = float(data['sustainability_score'])
        rec_date      = data.get('recommendation_date', '')

        db = get_db()
        cur = db.cursor()

        cur.execute("SELECT crop_id FROM Crop WHERE crop_name = %s", (crop_name,))
        row = cur.fetchone()
        if not row:
            cur.execute("SELECT crop_id FROM Crop WHERE crop_name LIKE %s", (f'%{crop_name}%',))
            row = cur.fetchone()
        if not row:
            db.close()
            return jsonify({'error': f'Crop "{crop_name}" not found'}), 404
        crop_id = row[0]

        if rec_date:
            cur.execute(
                "INSERT INTO Recommendation (land_id,crop_id,predicted_yield,sustainability_score,recommendation_date) "
                "VALUES (%s,%s,%s,%s,%s)",
                (land_id, crop_id, pred_yield, sust_score, rec_date)
            )
        else:
            cur.execute(
                "INSERT INTO Recommendation (land_id,crop_id,predicted_yield,sustainability_score) "
                "VALUES (%s,%s,%s,%s)",
                (land_id, crop_id, pred_yield, sust_score)
            )
        db.commit()
        rec_id = cur.lastrowid
        db.close()
        return jsonify({'success': True, 'recommendation_id': rec_id})
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


# ════════════════════════════════════════════
#  SMART RECOMMEND  (DB-driven, no external API)
# ════════════════════════════════════════════

@app.route('/api/smart-recommend', methods=['POST'])
def smart_recommend():
    """
    Scores crops by joining:
      crop  <->  crop_requirement  (N range, pH range)
    against the latest Soil_Test for the given land parcel.

    Scoring breakdown (100 pts total):
      Nitrogen match   : 35 pts  (from crop_requirement)
      pH match         : 30 pts  (from crop_requirement)
      Phosphorus fit   : 20 pts  (agronomic general ranges, no DB column)
      Potassium fit    : 15 pts  (agronomic general ranges, no DB column)
    Priority bonus     : +5 pts applied after capping at 100
    """
    try:
        data     = request.get_json()
        land_id  = int(data['land_id'])
        season   = data.get('season', '')
        priority = data.get('priority', 'Max Profit')

        db  = get_db()
        cur = db.cursor(dictionary=True)

        # ── Land / farmer / region ─────────────────────────────────────────
        cur.execute("""
            SELECT lp.area, lp.irrigation_type,
                   f.name  AS farmer,
                   r.region_name AS region
            FROM   Land_Parcel lp
            JOIN   Farmer f ON lp.farmer_id = f.farmer_id
            JOIN   Region r ON lp.region_id  = r.region_id
            WHERE  lp.land_id = %s
        """, (land_id,))
        land_row = cur.fetchone()
        if not land_row:
            db.close()
            return jsonify({'error': f'Land parcel {land_id} not found'}), 404

        # ── Latest soil test ───────────────────────────────────────────────
        cur.execute("""
            SELECT nitrogen_level   AS n,
                   phosphorus_level AS p,
                   potassium_level  AS k,
                   pH               AS ph,
                   organic_matter   AS om,
                   test_date
            FROM   Soil_Test
            WHERE  land_id = %s
            ORDER  BY test_date DESC
            LIMIT  1
        """, (land_id,))
        soil = cur.fetchone()
        if not soil:
            db.close()
            return jsonify({'error': 'No soil test found for this land parcel. Please add soil test data first.'}), 404

        # ── All crops joined with their requirements ───────────────────────
        # LEFT JOIN so crops without a crop_requirement row still appear
        cur.execute("""
            SELECT c.crop_id,
                   c.crop_name,
                   c.crop_type,
                   c.growth_duration,
                   c.water_requirement,
                   c.carbon_footprint,
                   c.avg_market_price,
                   cr.min_nitrogen,
                   cr.max_nitrogen,
                   cr.min_ph,
                   cr.max_ph,
                   cr.min_temp,
                   cr.max_temp,
                   cr.min_rainfall,
                   cr.max_rainfall
            FROM   crop c
            LEFT JOIN crop_requirement cr ON c.crop_id = cr.crop_id
        """)
        crops = cur.fetchall()
        db.close()

        soil_n  = float(soil['n']  or 0)
        soil_p  = float(soil['p']  or 0)
        soil_k  = float(soil['k']  or 0)
        soil_ph = float(soil['ph'] or 7)

        # General agronomic P/K adequacy ranges (kg/ha) used when DB has no column
        # Low < 25, Medium 25-50, High > 50  (P)
        # Low < 120, Medium 120-280, High > 280 (K)
        def p_score(p_val, max_pts=20):
            if p_val >= 25:   return max_pts          # adequate
            if p_val >= 15:   return int(max_pts * 0.7)
            return int(max_pts * 0.3)

        def k_score(k_val, max_pts=15):
            if k_val >= 120:  return max_pts          # adequate
            if k_val >= 80:   return int(max_pts * 0.7)
            return int(max_pts * 0.3)

        recommendations = []
        for c in crops:
            score = 0

            # ── Nitrogen (35 pts) ──────────────────────────────────────────
            mn = float(c['min_nitrogen'] or 0)
            mx = float(c['max_nitrogen'] or 999)
            if mn <= soil_n <= mx:
                score += 35
            else:
                gap = min(abs(soil_n - mn), abs(soil_n - mx))
                score += max(0, 35 - int(gap / 4))

            # ── pH (30 pts) ────────────────────────────────────────────────
            mn = float(c['min_ph'] or 4.5)
            mx = float(c['max_ph'] or 8.5)
            if mn <= soil_ph <= mx:
                score += 30
            else:
                gap = min(abs(soil_ph - mn), abs(soil_ph - mx))
                score += max(0, 30 - int(gap * 12))

            # ── Phosphorus (20 pts, general range) ────────────────────────
            score += p_score(soil_p)

            # ── Potassium (15 pts, general range) ─────────────────────────
            score += k_score(soil_k)

            score = max(0, min(100, score))

            # ── Priority bonus (+5, applied after cap) ────────────────────
            crop_type_lower = (c['crop_type'] or '').lower()
            water_val       = float(c['water_requirement'] or 500)
            duration_days   = int(c['growth_duration'] or 120)

            if priority == 'Sustainability' and ('pulse' in crop_type_lower or 'legume' in crop_type_lower):
                score = min(100, score + 5)
            elif priority == 'Low Water Use' and water_val < 400:
                score = min(100, score + 5)
            elif priority == 'Quick Harvest' and duration_days < 90:
                score = min(100, score + 5)
            elif priority == 'Max Profit':
                price = float(c['avg_market_price'] or 0)
                if price > 3000:
                    score = min(100, score + 5)

            # ── Human-readable water category ─────────────────────────────
            if water_val < 400:
                water_label = 'low'
            elif water_val <= 800:
                water_label = 'medium'
            else:
                water_label = 'high'

            # ── Yield & profit estimate ────────────────────────────────────
            area        = float(land_row['area'] or 1)
            # Rough yield: 3 t/acre baseline adjusted by organic matter bonus
            om_bonus    = 1 + (float(soil['om'] or 2) - 2) * 0.05
            est_yield   = round(3.0 * area * om_bonus, 2)
            price_per_q = float(c['avg_market_price'] or 2000)
            profit_val  = round(est_yield * 10 * price_per_q)   # tonnes → quintals

            duration_str = f"{duration_days} days"

            # ── pH status for reason text ──────────────────────────────────
            ph_lo = float(c['min_ph'] or 4.5)
            ph_hi = float(c['max_ph'] or 8.5)
            ph_status = 'optimal' if ph_lo <= soil_ph <= ph_hi else 'outside ideal range'

            reason = (
                f"Soil nitrogen ({soil_n} kg/ha) and pH {soil_ph} are {ph_status} for "
                f"{c['crop_name']}. Phosphorus ({soil_p} kg/ha) and potassium "
                f"({soil_k} kg/ha) levels support this crop's nutrient needs. "
                f"{land_row['irrigation_type']} irrigation in {land_row['region']} "
                f"suits its {water_label} water demand."
            )

            tips_map = {
                'low':    "Use drip or sprinkler irrigation to conserve water. Mulching helps retain soil moisture.",
                'medium': "Irrigate every 7–10 days. Monitor soil moisture and adjust based on rainfall.",
                'high':   "Ensure a reliable water source before sowing. Canal or flood irrigation is recommended.",
            }
            tips = tips_map[water_label]

            recommendations.append({
                'crop':     c['crop_name'],
                'type':     c['crop_type'] or 'Field Crop',
                'score':    score,
                'yield':    f"{est_yield} t",
                'profit':   f"₹{int(profit_val):,}",
                'duration': duration_str,
                'water':    water_label,
                'reason':   reason,
                'tips':     tips,
            })

        recommendations.sort(key=lambda x: x['score'], reverse=True)

        return jsonify({
            'land':            land_row['farmer'],
            'region':          land_row['region'],
            'soil_date':       str(soil['test_date']),
            'recommendations': recommendations[:5],
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


# ════════════════════════════════════════════
#  STATS
# ════════════════════════════════════════════

@app.route('/api/stats', methods=['GET'])
def get_stats():
    try:
        db = get_db()
        cur = db.cursor()
        cur.execute("SELECT COUNT(*) FROM Farmer")
        farmers = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM Land_Parcel")
        lands = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM Soil_Test")
        soils = cur.fetchone()[0]
        cur.execute("SELECT COUNT(*) FROM Recommendation")
        recs = cur.fetchone()[0]
        db.close()
        return jsonify({'farmers': farmers, 'lands': lands, 'soils': soils, 'recommendations': recs})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ════════════════════════════════════════════
#  REGIONS
# ════════════════════════════════════════════

@app.route('/api/regions', methods=['GET'])
def get_regions():
    try:
        db = get_db()
        cur = db.cursor(dictionary=True)
        cur.execute("SELECT region_id, region_name FROM Region ORDER BY region_name")
        rows = cur.fetchall()
        db.close()
        return jsonify(rows)
    except Exception as e:
        return jsonify({'error': str(e)}), 500


# ════════════════════════════════════════════
#  DEMO QUERIES
# ════════════════════════════════════════════

@app.route('/api/demo-query', methods=['POST'])
def run_demo_query():
    try:
        data = request.get_json()
        key = data.get('key')
        
        queries = {
            'sust': """
                SELECT f.name AS Farmer, rg.region_name AS Region, c.crop_name AS Crop, 
                       r.predicted_yield AS Yield, r.expected_profit AS Profit, 
                       r.sustainability_score AS Score
                FROM Recommendation r
                JOIN Land_Parcel lp ON r.land_id = lp.land_id
                JOIN Farmer f       ON lp.farmer_id = f.farmer_id
                JOIN Region rg      ON lp.region_id = rg.region_id
                JOIN Crop c         ON r.crop_id = c.crop_id
                WHERE r.sustainability_score > 80
            """,
            'match': """
                SELECT c.crop_name AS Crop, st.pH, st.nitrogen_level AS Nitrogen,
                CASE 
                    WHEN st.pH BETWEEN cr.min_ph AND cr.max_ph
                     AND st.nitrogen_level BETWEEN cr.min_nitrogen AND cr.max_nitrogen
                    THEN 'SUITABLE'
                    ELSE 'NOT SUITABLE'
                END AS Suitability
                FROM Soil_Test st
                CROSS JOIN Crop c
                JOIN Crop_Requirement cr ON c.crop_id = cr.crop_id
                WHERE st.land_id = 1
                LIMIT 15
            """,
            'profit': """
                SELECT c.crop_type AS Type, 
                       COUNT(*) AS Total_Recs,
                       ROUND(AVG(r.expected_profit),2) AS Avg_Profit,
                       ROUND(AVG(r.sustainability_score),2) AS Avg_Sustainability
                FROM Recommendation r
                JOIN Crop c ON r.crop_id = c.crop_id
                GROUP BY c.crop_type
                ORDER BY Avg_Profit DESC
            """,
            'yield': """
                SELECT lp.land_id AS Land_ID, f.name AS Farmer, 
                       r.predicted_yield AS Yield, c.crop_name AS Crop
                FROM Recommendation r
                JOIN Land_Parcel lp ON r.land_id = lp.land_id
                JOIN Farmer f       ON lp.farmer_id = f.farmer_id
                JOIN Crop c         ON r.crop_id = c.crop_id
                WHERE r.predicted_yield > (SELECT AVG(predicted_yield) FROM Recommendation)
            """,
            'sp': "CALL GetSuitableCrops(5)"
        }
        
        if key not in queries:
            return jsonify({'error': 'Invalid query key'}), 400
            
        db = get_db()
        cur = db.cursor(dictionary=True)
        cur.execute(queries[key])
        rows = cur.fetchall()
        db.close()
        
        # Handle decimal/date for JSON
        for r in rows:
            for k, v in r.items():
                if hasattr(v, 'decimal_value') or type(v).__name__ == 'Decimal':
                    r[k] = float(v)
                elif hasattr(v, 'isoformat'):
                    r[k] = v.isoformat()
                    
        return jsonify(rows)
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

# ════════════════════════════════════════════
#  CLAUDE AI PROXY
# ════════════════════════════════════════════

@app.route('/api/recommend', methods=['POST'])
def proxy_recommend():
    try:
        payload = request.get_json()
        print("Sending to Anthropic:", payload)  # debug
        
        if not ANTHROPIC_API_KEY:
            return jsonify({'error': 'ANTHROPIC_API_KEY not set on server'}), 500

        resp = _requests.post(
            'https://api.anthropic.com/v1/messages',
            headers={
                'x-api-key': ANTHROPIC_API_KEY,
                'anthropic-version': '2023-06-01',
                'content-type': 'application/json',
            },
            json=payload,
            timeout=60
        )
        resp_data = resp.json()
        print("Anthropic replied:", resp.status_code, resp_data)  # debug
        return jsonify(resp_data), resp.status_code
    except Exception as e:
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, port=5001)