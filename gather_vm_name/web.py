from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/webhook', methods=['POST'])
def webhook():
    data = request.get_json()  # 解析傳入的 JSON 資料
    if not data:
        return "Invalid JSON", 400
    
    # 處理接收到的 VM 名稱
    vm_names = data.get('vm_names', [])
    print("Received VM names:", vm_names)

    # 在此處可以將資料保存到檔案、資料庫，或做其他處理
    return jsonify({"status": "success", "received_vm_names": vm_names}), 200

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000)

