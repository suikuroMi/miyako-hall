# Project MIYAKO HALL

A 2D game built with Godot 4.x (.NET/C# & GDScript).

---

## 🔒 Proprietary Project Notice
**This project is private, confidential, and strictly closed-source.** Unauthorized copying, distribution, modification, or public hosting of this code base via any medium is prohibited.

All rights reserved by the development team.

---

## 🎮 Game Modes
- [ ] **Story Mode**
- [ ] **Endless Mode** 
- [ ] **Boss Rush Arena** 

---

## 🚀 Environment Setup

### Prerequisites
- Godot Engine 4.x (Mono/.NET Edition)
- .NET SDK

### Local Configuration
1. Pull the private repository to your workstation.
    - **HTTPS**
    ```bash
        git clone https://github.com/jimuelportugal/miyako-hall.git
    ```
    - **SSH**
    ```bash
        git clone git@github.com:jimuelportugal/miyako-hall.git
    ```
    - **GitHub CLI**
    ```bash
        gh repo clone jimuelportugal/miyako-hall
    ```
    

2. Open the project folder inside the Godot Editor to initialize metadata.
    - Launch the Godot Project Manager.
    - Click **Import**, navigate to your cloned directory, and select the `project.godot` file.
    - Open the project once to let the engine automatically generate the local `.godot/` tracking directory.
3. Open the root workspace folder in VS Code to sync the project assemblies (`.csproj`).
- Launch VS Code and open the repository folder.
    - If prompted, allow the C# / OmniSharp extension to initialize and parse the solution workspace.
    - Verify that your local workspace configurations are utilizing your system's global .NET execution path rather than pulling redundant runtime environments.
4. Click **Build** within the Godot editor interface to compile assemblies before running.
- Return to the active Godot Editor instance.
    - Click the **Build** button.
    - Confirm that the compilation logs return successfully without dependency or runtime blockages before running your test instances.

---


## 📜 Credits & Attributions

### Core Development Team
* **MENDOU** - Programming & Systems
* **GORIEE** - Programming & Systems
* **YUKI** - Lead Artist & Asset Designer (General Programming Support)