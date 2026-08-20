import subprocess

freecad = r"C:\Program Files\FreeCAD 1.1\bin\freecadcmd.exe"
analyzer = r"C:\ForgeMind\analyzer.py"
step_file = r"C:\ForgeMind\files\test.stp"

code = (
    "import sys; "
    f"sys.argv=['analyzer.py', r'{step_file}']; "
    f"exec(open(r'{analyzer}', encoding='utf-8').read())"
)

result = subprocess.run(
    [freecad, "-c", code],
    capture_output=True,
    text=True
)

print("STDOUT:")
print(result.stdout)

print("STDERR:")
print(result.stderr)

print("RETURN CODE:", result.returncode)