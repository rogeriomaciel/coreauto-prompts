import os
import json
import urllib.request
import urllib.error
from datetime import datetime

# --- CONFIGURAÇÃO ---
# 1. URL do seu Webhook n8n
WEBHOOK_URL = "https://logic.runoncore.com/app_test/atualizar-prompts-lojas"

# 2. Sua chave de segurança (exatamente como configurou no n8n)
API_KEY = "rogerioclemildabeatrizmiguel"

# 3. Caminho da pasta onde estão os prompts
PROMPTS_DIR = "/rogerio/core/coreauto-prompts"
# --------------------

def sync_files():
    print(f"🔄 Iniciando sincronização protegida de: {PROMPTS_DIR}")
    
    # Percorre todas as pastas e arquivos
    for root, dirs, files in os.walk(PROMPTS_DIR):
        if '.git' in dirs:
            dirs.remove('.git')
            
        for file in files:
            if file.endswith((".md", ".txt")):
                file_path = os.path.join(root, file)
                relative_name = os.path.relpath(file_path, PROMPTS_DIR)
                
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        
                    payload = {
                        "filename": relative_name,
                        "content": content,
                        "last_updated": datetime.now().isoformat()
                    }
                    
                    data = json.dumps(payload).encode('utf-8')
                    
                    # --- AQUI ESTÁ A MUDANÇA ---
                    # Adicionamos o cabeçalho 'api-key' junto com o Content-Type
                    headers = {
                        'Content-Type': 'application/json',
                        'api-key': API_KEY 
                    }
                    
                    req = urllib.request.Request(WEBHOOK_URL, data=data, headers=headers)
                    
                    with urllib.request.urlopen(req) as response:
                        if response.status == 200:
                            print(f"✅ Sucesso: {relative_name}")
                        else:
                            print(f"⚠️  Aviso ({response.status}): {relative_name}")
                            
                except urllib.error.HTTPError as e:
                    # Se der erro 401 ou 403, sabemos que é a chave
                    if e.code in [401, 403]:
                        print(f"⛔ ERRO DE PERMISSÃO: Verifique se a api-key está correta no script e no n8n.")
                    else:
                        print(f"❌ Erro HTTP {e.code}: {relative_name}")
                except Exception as e:
                    print(f"❌ Erro genérico: {e}")

if __name__ == "__main__":
    sync_files()