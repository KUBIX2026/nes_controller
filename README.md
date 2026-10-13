# Desarrollo del perifético NES 
En el presente repositorio se encuentran los avances producidos e información general para el desarrollo y conexión del períferico mando NES en la consola KUBIX. 

## ¿Qué se encuentra en este repositorio? 

##

### Master y slave 
En este caso, master es el módulo de la FPGA o el SoC encargado de controlar el NES
Slave es el mando físico del NES 
### Funcionamiento Interno del NES 
![Mapa NES](img/interno_nes.png)

## Protocolo de Comunicación del NES
Aproximadamente cada 16ms (al manejar 60Hz) se repite lo siguiente: 

![Protocolo Comunicaciones](img/protocolo_comunicaciones.png)

Latch es un pulso enviado por master que 'congela' el estado del 4021N interno en el mando físico de la NES. En el momento donde este pulso baja, automáticamente la línea Data revela el valor del primer bit, correspondiente al estado del botón 'A'. Posteriormente, se envia una secuencia de 7 pulsos para relevar los valores correspondientes a los demás botones. 

Sin embargo, el módulo maneja lógica 'inversa': Cuando está oprimido un botón, se obtiene '0' como valor, y cuando no está oprimido, se obtiene '1'. Por lo que cuando la línea Data llega a la FPGA, se le aplica una compuerta NOT. Por ejemplo, si en un ciclo se tiene start presionado: 

![Ejemplo Protocolo](img/protocolo_coms_ej.png)

## Pines del control NES

![Diagrama de los pines del control del Nes](image.png)

### Especificaciones del Protocolo de Comunicaciones 
* El protocolo opera mediante comunicación en serie y síncrona unidireccional
* La FPGA controla las líneas LATCH y CLOCK, y recibe DATA
* Se emplean niveles eléctricos estándar Transistor-Transistor Logic / Low-Voltage Transistor-Transistor Logic (5V o 3.3V), definiendo un umbral lógico bajo en $V_{IL} < 0.8\text{ V}$ y un umbral alto en $V_{IH} > 2.0\text{ V}$.
* DATA funciona con lógica negativa

### Verificación por Software Mediante Máscaras de Bit

| Botón a Verificar | Máscara Binaria | Máscara Hex | Condición en C | Resultado (Ej: Solo START = `0x08`) |
| :--- | :---: | :---: | :--- | :---: |
| **A** | `0000 0001` | `0x01` | `(data & 0x01) != 0` | `0` (Falso) |
| **B** | `0000 0010` | `0x02` | `(data & 0x02) != 0` | `0` (Falso) |
| **Select** | `0000 0100` | `0x04` | `(data & 0x04) != 0` | `0` (Falso) |
| **Start** | `0000 1000` | `0x08` | `(data & 0x08) != 0` | **`1` (Verdadero - Presionado)** |
| **Arriba** | `0001 0000` | `0x10` | `(data & 0x10) != 0` | `0` (Falso) |
| **Abajo** | `0010 0000` | `0x20` | `(data & 0x20) != 0` | `0` (Falso) |
| **Izquierda** | `0100 0000` | `0x40` | `(data & 0x40) != 0` | `0` (Falso) |
| **Derecha** | `1000 0000` | `0x80` | `(data & 0x80) != 0` | `0` (Falso) |


## Funcionamiento Interno del NES
![Diagrama de Flujo](<img/Diagrama de Flujo-Controlador NES.drawio(2).png>)
