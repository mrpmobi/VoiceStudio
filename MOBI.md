# VoiceStudio — deploy Mobi

Fork público: [mrpmobi/VoiceStudio](https://github.com/mrpmobi/VoiceStudio) (AGPL-3.0).

## Ambiente

- URL: https://voices.mrpmobi.com.br (Cloudflare Access; e-mail `marcelo@mrpmobi.com.br`)
- VPS: 62.169.25.190 (Docker Swarm)
- Branch de deploy: `mobi`
- Imagem: `ghcr.io/mrpmobi/voicestudio:mobi` e `:sha-<short>`
- Limites do serviço: 1.2 vCPU / 2400 MB RAM

## Como publicar uma alteração

1. Trabalhe na branch `mobi`.
2. Faça commit e `git push origin mobi`.
3. O workflow [Deploy Mobi](.github/workflows/deploy-mobi.yml) faz o build, publica no GHCR e atualiza o serviço na VPS.

## Upstream

- `origin` → este fork (`mrpmobi/VoiceStudio`)
- `upstream` → `debpalash/VoiceStudio`

Para puxar atualizações: `git fetch upstream` e merge/rebase na `mobi` com cuidado.
