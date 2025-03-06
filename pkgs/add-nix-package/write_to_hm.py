import os
import re

def ensure_autohm_imports(hmfilepath: str, autohmpath: str) -> None:
        hmpath = os.path.expanduser(hmfilepath)
        relative_import_path = os.path.expanduser(f"./{autohmpath.split("/")[-1]}")

        try:
            # Read existing content
            if os.path.exists(hmpath):
                with open(hmpath, "r") as file:
                    lines = file.readlines()
            else:
                lines = []

            # Patterns to detect the `home-manager.users` block
            user_block_pattern = re.compile(r"^\s*home-manager\.users\.[a-zA-Z0-9_-]+\s*=\s*\{")
            imports_pattern = re.compile(r"^\s*imports\s*=\s*\[")
            block_start_line = None
            block_end_line = None
            imports_line = None

            # Step 1: Find the `home-manager.users` block
            for i, line in enumerate(lines):
                if user_block_pattern.search(line):  # Found the user block start
                    block_start_line = i
                elif block_start_line is not None and line.strip() == "};":  # Found the block end
                    block_end_line = i
                    break
                elif block_start_line is not None and imports_pattern.search(line):  # Found imports line
                    imports_line = i

            if block_start_line is None or block_end_line is None:
                return

            users_block = lines[:]

            # Step 2: Modify or add the imports block inside the user block
            import_line = f"    {relative_import_path}\n"

            if imports_line is not None:  # If an imports block already exists
                # Check if autohmpath is already there
                if import_line.strip() not in [l.strip() for l in lines[imports_line + 1 : block_end_line]]:
                    users_block.insert(imports_line + 1, import_line)
            else:  # No imports block found, create one before `};`
                users_block.insert(block_start_line + 1, f"  imports = [\n{import_line}  ];\n")

            # Step 3: Write back the modified file
            with open(hmpath, "w") as file:
                file.writelines(users_block)

        except Exception as e:
            print(f"Error modifying {hmfilepath}: {e}")

def ensure_autohm_file(autohmpath: str) -> None:
    """
    Ensures that the autohmpath file exists. If it doesn't, creates it.

    :param autohmpath: Path to the auto-home-manager Nix file.
    """
    autohmpath = os.path.expanduser(autohmpath)  # Expand ~ to home directory

    if not os.path.exists(autohmpath):
        try:
            os.makedirs(os.path.dirname(autohmpath), exist_ok=True)  # Ensure parent directories exist

            # Write default structure to file
            with open(autohmpath, "w") as file:
                file.write("""\
{ pkgs, ... }:

{
  home.packages = [
    # Packages generated using the config script will go here.
  ];
}
""")
            print(f"Created {autohmpath} with default content.")

        except Exception as e:
            print(f"Error creating {autohmpath}: {e}")
    else:
        return
    

def add_package_to_autohm(autohmpath: str, pkgname: str) -> str:
    """
    Adds 'pkgs.pkgname' to the 'home.packages' block in autohmpath.
    If 'home.packages' does not exist, it creates one.
    
    :param autohmpath: Path to the auto_pkgs.nix file
    :param pkgname: The package name to be added as pkgs.pkgname
    :return Status message
    """
    autohmpath = os.path.expanduser(autohmpath)

    status = ""

    # Read the existing content
    if os.path.exists(autohmpath):
        with open(autohmpath, "r") as file:
            lines = file.readlines()
    else: # Make the file
        lines = ["{ pkgs, ... }:\n", "\n", "{\n", "  home.packages = [\n", "  ];\n", "};\n"]

    # Ensure home.packages block exists
    in_packages_block = False
    packages_start = None
    packages_end = None

    for i, line in enumerate(lines):
        if re.search(r"^\s*home\.packages\s*=\s*\[", line):  # Start of block
            in_packages_block = True
            packages_start = i
        elif in_packages_block and re.search(r"^\s*\];", line):  # End of block
            packages_end = i
            break

    if packages_start is None or packages_end is None:
        # If home.packages doesn't exist, create it before closing `};`
        for i, line in enumerate(lines):
            if line.strip() == "};":  # Insert before closing brace
                lines.insert(i, "  home.packages = [\n  ];\n")
                packages_start = i
                packages_end = i + 1
                break

    # Define the package line
    package_line = f"    pkgs.{pkgname}\n"

    # Check if package already exists
    existing_packages = [line.strip() for line in lines[packages_start + 1 : packages_end]]
    
    if package_line.strip() not in existing_packages:
        # Insert before the closing bracket of home.packages
        lines.insert(packages_end, package_line)
    else:
        status = "Package already in file."

    # Write back to the file
    with open(autohmpath, "w") as file:
        file.writelines(lines)
    
    return status


if __name__ == "__main__":
    HMPATH = "~/.remote/home-manager.nix"
    AUTO_HM_FILEPATH = "~/.remote/auto-pkgs.nix"
    ensure_autohm_imports(HMPATH, AUTO_HM_FILEPATH)
    ensure_autohm_file(AUTO_HM_FILEPATH)
    add_package_to_autohm(AUTO_HM_FILEPATH, "test2")