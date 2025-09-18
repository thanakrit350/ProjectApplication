# OSM Importer (Chiang Mai Restaurants)

## Setup
```bash
cd tools/importers/osm
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# แก้ค่าใน .env ให้ชี้ไปที่ API ของคุณ
export $(grep -v '^#' .env | xargs)   # โหลด env (macOS/Linux)
