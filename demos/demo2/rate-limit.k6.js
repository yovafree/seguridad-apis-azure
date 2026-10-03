// Demo 2: prueba de carga con k6 que dispara el rate limit de APIM.
//
// Uso (las variables salen de demos/.env):
//   demos/demo2/k6.sh
// o manualmente:
//   k6 run -e API_URL=https://<apim>.azure-api.net/demo2 -e SUBSCRIPTION_KEY=... demos/demo2/rate-limit.k6.js
//
// 2 solicitudes/segundo durante 30 s = 60 llamadas. Con 10 llamadas/60 s permitidas,
// se esperan ~10 respuestas 2xx y ~50 respuestas 429.

import http from 'k6/http';
import { Counter } from 'k6/metrics';

const API_URL = __ENV.API_URL;
const SUBSCRIPTION_KEY = __ENV.SUBSCRIPTION_KEY;

const status2xx = new Counter('status_2xx');
const status429 = new Counter('status_429');
const statusOther = new Counter('status_otros');

export const options = {
  scenarios: {
    rafaga: {
      executor: 'constant-arrival-rate',
      rate: 2,
      timeUnit: '1s',
      duration: '30s',
      preAllocatedVUs: 5,
    },
  },
  // La demo "pasa" si APIM efectivamente limitó las llamadas.
  thresholds: {
    status_429: ['count>0'],
  },
};

// Un 429 es el comportamiento esperado: no lo contamos como request fallido.
http.setResponseCallback(http.expectedStatuses({ min: 200, max: 299 }, 429));

export function setup() {
  if (!API_URL || !SUBSCRIPTION_KEY) {
    throw new Error('Faltan API_URL o SUBSCRIPTION_KEY (ejecuta scripts/export-env.sh)');
  }
}

export default function () {
  const headers = { 'Ocp-Apim-Subscription-Key': SUBSCRIPTION_KEY };
  const res = http.get(`${API_URL}/orders`, { headers });

  if (res.status >= 200 && res.status < 300) {
    status2xx.add(1);
  } else if (res.status === 429) {
    status429.add(1);
  } else {
    statusOther.add(1);
  }
}

export function handleSummary(data) {
  const count = (name) => (data.metrics[name] ? data.metrics[name].values.count : 0);
  const total = count('http_reqs');
  const lines = [
    '',
    '=== Códigos de estado ===',
    `  Total: ${total}`,
    `  2xx:   ${count('status_2xx')}`,
    `  429:   ${count('status_429')}`,
    `  Otros: ${count('status_otros')}`,
    '',
  ];
  return { stdout: lines.join('\n') };
}
