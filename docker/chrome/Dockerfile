# ADR-0007/0008: tag fixa, nunca latest. Trocar a tag troca o Chrome do login; o próximo login
# registra o alerta de atualização da imagem.
FROM selenium/standalone-chrome:153.0

# O volume nomeado herda o dono da pasta da imagem. Sem este mkdir, a pasta nasceria do root e o
# seluser não conseguiria gravar o perfil.
USER seluser
RUN mkdir -p /home/seluser/browser-profile
