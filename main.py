from fastapi import FastAPI, Request, Response
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import uuid

# Create FastAPI app
app = FastAPI(title="FastAPI Example Project", version="1.0.0")

# Mount static folder
app.mount("/static", StaticFiles(directory="static"), name="static")

# Setup Jinja2 templates
templates = Jinja2Templates(directory="templates")

# -------------------------------
# Root route (HTML homepage)
# -------------------------------
@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    return templates.TemplateResponse("home.html", {"request": request})

# -------------------------------
# Example API endpoint
# -------------------------------
@app.get("/api/info", response_class=JSONResponse)
async def api_info(response: Response):
    response.headers["X-Server-ID"] = str(uuid.uuid4())
    return {
        "message": "Hello from FastAPI!",
        "version": "1.0.0",
        "status": "running"
    }
