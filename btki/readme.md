# Multi-omics Analysis Shiny App

## Quick Start

### 1. Install Dependencies
```r
install.packages("shinymanager")
```

### 2. Initialize User Database
Simply run the initialization script (SM_PASSPHRASE is optional):
```bash
Rscript init_db.R
```


>(Optional) If you want to use a custom passphrase for production:
>```bash
>echo "SM_PASSPHRASE=123123" > ./.Renviron
> Rscript init_db.R
>```

### 3. Run the Application

**Option A: Direct Run (Development)**
```bash
Rscript app.R
```

### 4. Login
Default credentials:
- **Admin**: `admin` / `Admin#123`
- **Demo**: `demo` / `Demo#123`
- **Novartis**: `Novartis` / `Novartis#123`

You can manage users in the admin panel after logging in.
