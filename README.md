 <img src="https://github.com/user-attachments/assets/fea1c27c-f8d4-4867-992c-f187215338a5" width="40" align="center" alt="Ícone DriverWatch"> DriverWatch - Sistema de Segurança Veicular (Edge Computing) DriverWatch - Sistema de Segurança Veicular (Edge Computing)

[![Flutter](https://img.shields.io/badge/Flutter-Cross--Platform-02569B?logo=flutter)](https://flutter.dev/)
[![Android](https://img.shields.io/badge/Android-Native_Bridge-3DDC84?logo=android)](https://developer.android.com/)
[![ML Kit](https://img.shields.io/badge/Google-ML_Kit-4285F4?logo=google)](https://developers.google.com/ml-kit)
[![Status](https://img.shields.io/badge/Status-Protótipo_Acadêmico-success)](#)

> **Trabalho de Conclusão de Curso - Sistemas de Informação (UEMG Passos)** > **Autores:** Amanda Rodrigues Agelune e Thalles José Guilherme da Silva

O **DriverWatch** é um protótipo de aplicativo móvel focado em segurança viária ativa. Ele utiliza a câmera frontal e os sensores inerciais de um smartphone comum para detectar sinais de fadiga, distração e colisões severas em tempo real, operando 100% offline por meio do paradigma de *Edge Computing*.

---

## ✨ Principais Funcionalidades

* **👁️ Monitoramento de Sonolência:** Calcula a probabilidade de fechamento ocular (EAR - Eye Aspect Ratio) via redes neurais.
* **👤 Alerta de Distração:** Monitora os ângulos de rotação da cabeça (Yaw e Pitch) para garantir o foco contínuo na via.
* **💥 Detecção de Colisão Inercial:** Analisa os eixos do acelerômetro; impactos severos (> 4.5 G) ativam o protocolo de resgate automaticamente.
* **🚑 Protocolo SOS Autônomo:** Em caso de colisão, envia um SMS com a localização atual (link do Google Maps) e realiza uma chamada direta para serviços de emergência via integração nativa em Kotlin.
* **📱 Modo Janela Flutuante (Picture-in-Picture):** Executa em segundo plano, sobrepondo-se a aplicativos de navegação como Waze ou Google Maps.

---

## 📸 Telas do Aplicativo

| Modo Janela Flutuante | Alerta de Sonolência | Alerta de Distração | Protocolo SOS |
| :---: | :---: | :---: | :---: |
| <img src="https://github.com/user-attachments/assets/4fef0d75-23b5-437e-b316-bb888f6f632e" width="200" alt="Monitoramento Ativo"> | <img src="https://github.com/user-attachments/assets/67c7c639-5f5f-4091-bc18-b9f1178496b7" width="200" alt="Alerta de Sonolência"> | <img src="https://github.com/user-attachments/assets/eb5f5b47-c83c-4376-902c-0352e24156ce" width="200" alt="Alerta de Distração"> | <img src="https://github.com/user-attachments/assets/7df2a8b2-4c99-4283-b5f2-829c61a7e484" width="200" alt="Protocolo SOS"> |

---

## ⚙️ Arquitetura e Tecnologias

O projeto foi construído utilizando uma arquitetura assíncrona orientada a eventos para garantir que o processamento das imagens não bloqueie a leitura dos sensores físicos:

* **Frontend/UI:** Flutter (Dart) com motor de renderização Skia/Impeller.
* **Visão Computacional:** Google ML Kit Face Detection (processamento 100% local no dispositivo).
* **Telemetria:** Pacote `sensors_plus` para extração vetorial dos dados do acelerômetro.
* **Integração Nativa:** Utilização de `MethodChannel` para conectar o Dart ao ecossistema Kotlin (Android API), permitindo forçar a maximização da tela (`bringToFront`) e realizar o fracionamento para envios de SMS de emergência (`SmsManager`).

---

## 🚀 Como Executar o Projeto

1. Clone este repositório em sua máquina local:

    ```bash
    git clone [https://github.com/SEU_USUARIO/driverwatch.git](https://github.com/SEU_USUARIO/driverwatch.git)
    ```

2. Acesse a pasta do projeto:

    ```bash
    cd driverwatch
    ```

3. Instale as dependências baixando os pacotes necessários do Flutter:

    ```bash
    flutter pub get
    ```

4. Conecte um dispositivo Android físico com o modo Depuração USB habilitado.

    > **Importante:** O DriverWatch utiliza câmera frontal, acelerômetro e recursos nativos do Android. Portanto, os testes devem ser realizados em um dispositivo físico, pois emuladores podem não oferecer suporte completo aos sensores utilizados pelo sistema.

5. Inicie o projeto com o comando:

    ```bash
    flutter run
    ```
