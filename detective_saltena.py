import os
import sqlite3
from pathlib import Path

def ejecutar_diagnostico():
    print("=" * 60)
    print(" 🕵️‍♂️ DIAGNÓSTICO DE PERSISTENCIA Y RELEASE")
    print("=" * 60)

    raiz = Path(r"C:\SALTENA")
    print(f"\n[1] Ruta raíz: {raiz} (Existe: {raiz.exists()})")

    release_exe = raiz / "build" / "windows" / "x64" / "runner" / "Release" / "AScafe.exe"
    print(f"\n[2] Ejecutable Release: {release_exe.exists()} -> {release_exe}")

    docs_usuario = Path(os.environ.get("USERPROFILE", "")) / "Documents"
    db_ruta = docs_usuario / "AScafe_Data" / "salteceria.db"
    print(f"\n[3] Base de datos SQLite en documentos: {db_ruta.exists()} -> {db_ruta}")

    if db_ruta.exists():
        try:
            conexion = sqlite3.connect(str(db_ruta))
            cursor = conexion.cursor()
            cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
            tablas = [row[0] for row in cursor.fetchall()]
            print(f"\n[4] Tablas encontradas: {tablas}")
            for t in tablas:
                cursor.execute(f"SELECT COUNT(*) FROM {t}")
                print(f"    - {t}: {cursor.fetchone()[0]} filas")
            conexion.close()
        except Exception as e:
            print(f"    ❌ Error leyendo la base de datos: {e}")
    else:
        print("    ❌ El archivo de base de datos no existe en documentos.")

if __name__ == "__main__":
    ejecutar_diagnostico()
