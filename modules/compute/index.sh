<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Jump Host Dashboard — babenkov.pp.ua</title>
<style>
body {
    font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
    background: #f4f7fa;
    margin: 0;
    color: #333;
}
header {
    background: linear-gradient(135deg, #4facfe, #00f2fe);
    color: white;
    text-align: center;
    padding: 40px 20px;
}
header h1 {
    font-size: 2.5rem;
    margin-bottom: 10px;
}
header p {
    font-size: 1.2rem;
}
main {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 20px;
    padding: 40px 20px;
}
.card {
    background: white;
    border-radius: 12px;
    box-shadow: 0 6px 15px rgba(0,0,0,0.1);
    padding: 20px 30px;
    width: 250px;
    text-align: center;
    transition: transform 0.2s;
}
.card:hover { transform: translateY(-5px); }
.card h2 { font-size: 1.5rem; margin-bottom: 10px; color: #4facfe; }
.card p { font-size: 1rem; margin-bottom: 15px; }
.status {
    font-weight: bold;
}
.status.online { color: green; }
.status.offline { color: red; }
.card a {
    display: inline-block;
    text-decoration: none;
    background: #4facfe;
    color: white;
    padding: 8px 15px;
    border-radius: 8px;
    transition: background 0.2s;
}
.card a:hover { background: #00f2fe; }
</style>
</head>
<body>

<header>
<h1>Jump Host — babenkov.pp.ua</h1>
<p>Service status dashboard</p>
</header>

<main>
    <div class="card">
        <h2>Nginx</h2>
        <p>Status: <span class="status" id="status-nginx">Checking...</span></p>
        <a href="https://babenkov.pp.ua" target="_blank">Go to Nginx</a>
    </div>

    <div class="card">
        <h2>Elasticsearch</h2>
        <p>Status: <span class="status" id="status-es">Checking...</span></p>
        <a href="https://elasticsearch.babenkov.pp.ua" target="_blank">Go to ES</a>
    </div>

    <div class="card">
        <h2>Kibana</h2>
        <p>Status: <span class="status" id="status-kb">Checking...</span></p>
        <a href="https://kibana.babenkov.pp.ua" target="_blank">Go to Kibana</a>
    </div>
</main>

<script>
async function checkStatus(url, elementId) {
    try {
        const res = await fetch(url, { method: 'GET', mode: 'no-cors' });
        document.getElementById(elementId).textContent = "Online";
        document.getElementById(elementId).className = "status online";
    } catch (e) {
        document.getElementById(elementId).textContent = "Offline";
        document.getElementById(elementId).className = "status offline";
    }
}

// Check services via HTTPS
checkStatus('https://babenkov.pp.ua', 'status-nginx');
checkStatus('https://elasticsearch.babenkov.pp.ua', 'status-es');
checkStatus('https://kibana.babenkov.pp.ua', 'status-kb');
</script>

</body>
</html>
