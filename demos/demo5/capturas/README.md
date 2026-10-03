# Capturas — demo5 (plan B)

Guarda aquí, durante el ensayo, las capturas y las salidas reales:

```bash
NO_PAUSE=1 demos/demo5/lockdown.sh | tee demos/demo5/capturas/salida.txt
```

Checklist:

- [ ] Portal: Container App <prefijo>-orders-locked > Ingress > IP restrictions
- [ ] Portal: Container App <prefijo>-orders-locked > Authentication
- [ ] Terminal: lockdown.sh con 200 / 403 / 200
