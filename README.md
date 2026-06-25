# 🚘 DriverWatch - Sistema de Segurança Veicular (Edge Computing)

[![Flutter](https://img.shields.io/badge/Flutter-Cross--Platform-02569B?logo=flutter)](https://flutter.dev/)
[![Android](https://img.shields.io/badge/Android-Native_Bridge-3DDC84?logo=android)](https://developer.android.com/)
[![ML Kit](https://img.shields.io/badge/Google-ML_Kit-4285F4?logo=google)](https://developers.google.com/ml-kit)
[![Status](https://img.shields.io/badge/Status-Protótipo_Acadêmico-success)](#)

> **Trabalho de Conclusão de Curso - Sistemas de Informação (UEMG Passos)** > Autores: Amanda Rodrigues Agelune e Thalles José Guilherme da Silva

O **DriverWatch** é um protótipo de aplicativo móvel focado em segurança viária ativa. Ele utiliza a câmera frontal e os sensores inerciais de um smartphone comum para detectar sinais de fadiga, distração e colisões severas em tempo real, operando 100% offline através do paradigma de *Edge Computing*.

---

## ✨ Principais Funcionalidades

* **👁️ Monitoramento de Sonolência:** Calcula a probabilidade de abertura ocular (EAR) via redes neurais.
* **👤 Alerta de Distração:** Monitora os ângulos da cabeça (Yaw e Pitch) para garantir o foco na pista.
* **💥 Detecção de Colisão Inercial:** Monitora os eixos do acelerômetro; impactos severos (> 4.5 G) ativam o protocolo de resgate.
* **🚑 Protocolo SOS Autônomo:** Em caso de colisão, envia um SMS com link do Google Maps e faz uma ligação direta para emergência via canal nativo Kotlin.
* **📱 Modo Janela Flutuante (PiP):** Roda minimizado sobrepondo-se a aplicativos de GPS como Waze ou Google Maps.

---

## 📸 Telas do Aplicativo

| Monitoramento Ativo | Alerta de Sonolência | Alerta de Distração |Protocolo SOS |
| :---: | :---: | :---: |
| <img src="https://github.com/user-attachments/assets/4fef0d75-23b5-437e-b316-bb888f6f632e" width="200"> | <img src="https://github.com/user-attachments/assets/67c7c639-5f5f-4091-bc18-b9f1178496b7" width="200"> | <img src="https://github.com/user-attachments/assets/eb5f5b47-c83c-4376-902c-0352e24156ce" />  | <img src="https://github.com/user-attachments/assets/7df2a8b2-4c99-4283-b5f2-829c61a7e484" width="200" />


---

## ⚙️ Arquitetura e Tecnologias

O projeto foi construído utilizando uma arquitetura assíncrona para garantir que a leitura de imagens não bloqueie a leitura dos sensores físicos:

* **Frontend/UI:** Flutter (Dart) com renderização Skia/Impeller.
* **Visão Computacional:** Google ML Kit Face Detection (processamento local no dispositivo).
* **Telemetria:** Pacote `sensors_plus` para extração vetorial do acelerômetro.
* **Integração Nativa:** Uso de `MethodChannel` conectando o Dart ao ecossistema Kotlin (Android API) para forçar maximização de tela (`bringToFront`) e fracionamento de envios de SMS (`SmsManager`).

---

## 🚀 Como Executar o Projeto

1. Clone este repositório:
   ```bash
   git clone [https://github.com/SEU_USUARIO/driverwatch.git](https://github.com/SEU_USUARIO/driverwatch.git)

2. Instale as dependências do Flutter:
 ```bash
flutter pub get

3.Conecte um dispositivo físico Android.

4.Execute o aplicativo:
  ```bash
flutter run
