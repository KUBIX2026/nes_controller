#  Verificación de Botones

```mermaid
flowchart TD
    subgraph Hardware
        CSR[Registro CSR 0x450000]
    end

    subgraph Capa Driver Firmware C
        READ[Muestreo del Registro]
        SANITY{Revisar si el valor es 0xFF}
        MASK[Enmascaramiento Bitwise AND]
        EDGE[Calculadora de Flancos]
        SANITY_DIR{Filtro de Exclusión Mutua}
    end

    subgraph Capa Aplicación / Juego
        EVENT[Despachador de Eventos]
    end

    CSR --> READ --> SANITY
    SANITY -->|Valor 0xFF| ERR[Alerta: Cortocircuito a GND]
    SANITY -->|Cualquier otro valor| MASK
    MASK --> EDGE --> SANITY_DIR
    SANITY_DIR --> EVENT
```

---

# Enmascaramiento Bitwise AND

Filtro para aislar la presencia de cada botón dentro del byte recibido.

| Botón | Máscara Hexadecimal | Máscara Binaria | Condición Lógica en C |
| :--- | :---: | :---: | :--- |
| Botón A | `0x01` | `00000001` | `(trama & 0x01) != 0` |
| Botón B | `0x02` | `00000010` | `(trama & 0x02) != 0` |
| Select | `0x04` | `00000100` | `(trama & 0x04) != 0` |
| Start | `0x08` | `00001000` | `(trama & 0x08) != 0` |
| Arriba (Up) | `0x10` | `00010000` | `(trama & 0x10) != 0` |
| Abajo (Down) | `0x20` | `00100000` | `(trama & 0x20) != 0` |
| Izquierda (Left) | `0x40` | `01000000` | `(trama & 0x40) != 0` |
| Derecha (Right) | `0x80` | `10000000` | `(trama & 0x80) != 0` |

---

# Detección de Flancos

Cálculo del cambio de estado mediante la comparación entre la trama del ciclo actual (`current`) y el ciclo previo (`previous`).

```mermaid
flowchart LR
    subgraph Entradas de Lectura
        CURR[Trama Actual: current]
        PREV[Trama Anterior: previous]
    end

    subgraph Operaciones Bitwise
        AND_P[current & ~previous]
        AND_R[~current & previous]
        AND_H[current & previous]
    end

    subgraph Estados Resultantes
        BTN_PRESS[Recién Presionado: pressed]
        BTN_REL[Recién Soltado: released]
        BTN_HOLD[Mantenido Oprimido: held]
    end

    CURR --> AND_P
    PREV --> AND_P
    AND_P --> BTN_PRESS

    CURR --> AND_R
    PREV --> AND_R
    AND_R --> BTN_REL

    CURR --> AND_H
    PREV --> AND_H
    AND_H --> BTN_HOLD
```

---

# Sanitización de Direcciones Opuestas

Corrección de datos inválidos por colisión física en la cruceta (direcciones opuestas simultáneas).

```mermaid
flowchart TD
    A[Trama Infiltrada en Mapeo] --> B{¿Arriba Y Abajo Activos?}
    B -->|Sí: Violación Física| C[Forzar Bits Arriba y Abajo a 0]
    B -->|No: Estado Válido| D{¿Izquierda Y Derecha Activos?}
    C --> D
    D -->|Sí: Violación Física| E[Forzar Bits Izquierda y Derecha a 0]
    D -->|No: Estado Válido| F[Trama Sanitizada Lista para la CPU]
    E --> F
```

---

# Implementación en C

```c
#include <stdint.h>

#define NES_PORT_ADDR 0x450000
#define IO_NES        (*((volatile uint32_t *)NES_PORT_ADDR))

#define NES_MASK_A      0x01
#define NES_MASK_B      0x02
#define NES_MASK_SELECT 0x04
#define NES_MASK_START  0x08
#define NES_MASK_UP     0x10
#define NES_MASK_DOWN   0x20
#define NES_MASK_LEFT   0x40
#define NES_MASK_RIGHT  0x80

typedef struct {
    uint8_t current;   // botones presionados ahora
    uint8_t pressed;   // recién presionados
    uint8_t released;  // recién soltados
    uint8_t held;      // siguen presionados
} NES_Controller;

static uint8_t previous_frame = 0;

void nes_update(NES_Controller *pad) {
    uint8_t raw = (uint8_t)(IO_NES & 0xFF);

    // 0xFF = los 8 botones a la vez: no pasa en un mando real.
    // Se toma como cortocircuito a GND y se ignora.
    if (raw == 0xFF) {
        raw = 0;
    }

    // Dos direcciones opuestas a la vez tampoco son posibles: se ignoran
    if ((raw & NES_MASK_UP) && (raw & NES_MASK_DOWN))    raw &= ~(NES_MASK_UP | NES_MASK_DOWN);
    if ((raw & NES_MASK_LEFT) && (raw & NES_MASK_RIGHT)) raw &= ~(NES_MASK_LEFT | NES_MASK_RIGHT);

    // Cálculo de flancos
    pad->current  = raw;
    pad->pressed  = raw & ~previous_frame;
    pad->released = ~raw & previous_frame;
    pad->held     = raw & previous_frame;

    previous_frame = raw;
}
```
