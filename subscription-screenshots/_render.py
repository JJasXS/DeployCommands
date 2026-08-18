"""Render login HTML snapshots and screenshot them with Chrome."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
EQ = Path(r"c:\Users\sqlsupport\eQuotation")
CSS_THEME = (EQ / "static/css/equotationIcyTheme.css").as_uri()
CSS_LOGIN = (EQ / "static/css/login.css").as_uri()
LOGO = (EQ / "static/images/equote_logo.png").as_uri()
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

STATES = [
    {
        "file": "7-days",
        "expired": False,
        "title": "Your subscription expires in 7 days.",
        "body": "",
        "detail": "",
        "btn": "Renew Subscription",
    },
    {
        "file": "3-days",
        "expired": False,
        "title": "Your subscription expires in 3 days.",
        "body": "Please renew soon to avoid service interruption.",
        "detail": "",
        "btn": "Renew Subscription",
    },
    {
        "file": "1-day",
        "expired": False,
        "title": "Your subscription expires tomorrow.",
        "body": "Please renew to maintain uninterrupted access.",
        "detail": "",
        "btn": "Renew Subscription",
    },
    {
        "file": "expired",
        "expired": True,
        "title": "Subscription Expired",
        "body": "Your subscription has expired.",
        "detail": "Please contact ProAcc System to renew your subscription and restore access.",
        "btn": "Contact Support",
    },
]


def page(state: dict) -> str:
    expired_cls = " is-license-expired" if state["expired"] else ""
    overlay = ""
    if state["expired"]:
        overlay = f"""
    <div class="login-license-lockout" role="alertdialog" aria-modal="true">
        <div class="login-license-lockout__card">
            <div class="login-license-lockout__emoji" aria-hidden="true">🔒</div>
            <h1 class="login-license-lockout__title">{state["title"]}</h1>
            <p class="login-license-lockout__lead">{state["body"]}</p>
            <p class="login-license-lockout__hint">{state["detail"]}</p>
            <a class="login-license-wa" href="#">{state["btn"]}</a>
        </div>
    </div>"""
    banner = ""
    if not state["expired"]:
        body_html = (
            f'<div class="login-license-left__body">{state["body"]}</div>'
            if state["body"]
            else ""
        )
        banner = f"""
                        <div class="login-license-left" role="status">
                            <div class="login-license-left__title">{state["title"]}</div>
                            {body_html}
                            <a class="login-license-wa login-license-wa--compact" href="#">{state["btn"]}</a>
                        </div>"""
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{state["file"]}</title>
    <link rel="stylesheet" href="{CSS_THEME}">
    <link rel="stylesheet" href="{CSS_LOGIN}">
    <style>
      .login-carousel-slide {{ width: 100%; }}
      .login-carousel-track {{ transform: none; }}
    </style>
</head>
<body class="equotation-icy-theme login-page-body{expired_cls}">
{overlay}
    <div class="login-page">
        <aside class="login-aside">
            <div class="login-aside-header">
                <p class="login-aside-kicker">Sign in as</p>
                <p class="login-aside-hint">Choose your account type. We look up your email only in that directory.</p>
            </div>
            <div class="login-carousel-viewport">
                <div class="login-carousel-track">
                    <button type="button" class="login-carousel-slide is-active">
                        <span class="login-carousel-icon" aria-hidden="true">🛒</span>
                        <span class="login-carousel-title">Customer</span>
                        <span class="login-carousel-desc">Quotations and orders for AR customer or branch</span>
                    </button>
                </div>
            </div>
            <div class="login-carousel-nav">
                <button type="button" class="login-carousel-arrow">‹</button>
                <div class="login-carousel-dots">
                    <button class="login-carousel-dot" type="button"></button>
                    <button class="login-carousel-dot" type="button" aria-current="true"></button>
                    <button class="login-carousel-dot" type="button"></button>
                </div>
                <button type="button" class="login-carousel-arrow">›</button>
            </div>
        </aside>
        <div class="login-main">
            <div class="login-container">
                <div class="login-brand">
                    <img src="{LOGO}" alt="ProAcc eQuotation" class="login-logo" />
                </div>
                <div class="login-card">
                    <div id="email-step" class="login-step active">
                        <form>
                            <div class="form-group">
                                <label for="email">Email Address</label>
                                <input type="email" id="email" placeholder="your@email.com" />
                            </div>
                            <button type="button" class="btn-submit">Continue</button>
                        </form>
                        <a href="#" class="btn-guest">Sign in as Guest</a>
                    </div>
                    <div class="login-meta">
{banner}
                        <div>Managed by ProAcc System.</div>
                        <div class="login-version">V1.0</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</body>
</html>
"""


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    user_data = ROOT / "_chrome-profile"
    user_data.mkdir(exist_ok=True)
    for state in STATES:
        html_path = ROOT / f"{state['file']}.html"
        png_path = ROOT / f"{state['file']}.png"
        html_path.write_text(page(state), encoding="utf-8")
        subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--force-device-scale-factor=2",
                "--window-size=1440,900",
                f"--user-data-dir={user_data}",
                f"--screenshot={png_path}",
                html_path.as_uri(),
            ],
            check=True,
        )
        print(png_path)


if __name__ == "__main__":
    main()
