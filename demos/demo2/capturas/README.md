# Capturas — demo2 (plan B)

Guarda aquí, durante el ensayo, las capturas y las salidas reales:

```bash
NO_PAUSE=1 demos/demo2/rate-limit.sh | tee demos/demo2/capturas/salida.txt
```

Checklist:

- [ ] Portal: política de *Demo 2 - Rate limit y cuota* con los include-fragment
- [ ] Terminal: rate-limit.sh demo1 (15 x 200) y rate-limit.sh (10 x 200, 5 x 429) con el detalle ProblemDetails
- [ ] Terminal: resumen de k6
- [ ] Log Analytics: gráfico de columnas de la consulta 1 (queries.kql)
