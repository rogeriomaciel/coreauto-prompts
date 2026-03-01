#!/bin/bash
# Adiciona todas as mudanças nos textos
git add .; git commit -m "Update Intelligence: $(date)"; git push;


python3 sync_prompts.py