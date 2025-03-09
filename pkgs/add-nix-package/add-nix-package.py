from textual.app import App, ComposeResult
from textual.containers import Container
from textual.widgets import Input, Button, Label, ListView, ListItem, Log, Static
from textual.binding import Binding
import json
import subprocess
import os
from write_to_hm import *

#TODO Allow unfree packages?

AUTO_HM_FILEPATH = "~/.remote/auto-pkgs.nix"
HM_FILEPATH = "~/.remote/.home-manager.nix"

class LabelItem(ListItem):
    def __init__(self, label):
        super().__init__()
        self.label = label

    def compose(self) -> ComposeResult:
        yield Label(self.label)

class NixPackageSearchTUI(App):
    pkg_list = []
    if os.path.exists("styles.css"):
        CSS_PATH = "styles.css"  # Optional: Add styles if needed

    BINDINGS = [
        Binding("enter", "handle_enter", "Search for the package or add to the list.", show=False, priority=True),
        ("esc", "quit", "Quit the application"),
    ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.nix_search_command = self.detect_nix_search_command()

    def detect_nix_search_command(self) -> str:
        """Detect the appropriate nix search command based on the OS."""
        try:
            if "Nix" in os.uname().version:
                return "nix search"
            else:
                return "nix-search"
        except AttributeError:
            # Fallback if os.uname() is not available
            return "nix-search"

    def compose(self) -> ComposeResult:
        """Define the TUI layout."""
        yield Container(
            Label("Nix Package Search", id="title"),
            Input(placeholder="Enter package name...", id="package_input", restrict=r"[\w\-]*"),
            ListView(id="results_list"),
            Button("Add Selected Package to Home Manager", id="add_button"),
            Log("Status", id="status"),
        )
        

    async def on_mount(self) -> None:
        """Run actions when the app starts."""
        self.query_one("#add_button").disabled = True  # Disable Add button initially
        title = self.query_one('#title')
        title.styles.background = "blue"
        self.query_one('#results_list').styles.height = 10
        self.log_widget = self.query_one('#status')

    async def action_search(self) -> None:
        """Handle the search action."""
        package_input = self.query_one("#package_input").value.strip()
        results_list = self.query_one("#results_list")
        # self.screen.focus_next(selector='#results_list')

        if not package_input:
            return  # No input to search
        
        self.log_widget.write_line("Searching packages...")
        
        command = self.nix_search_command.split() + ["--max-results", "10", "--json", package_input]
        output = subprocess.check_output(command).split(b'\n')
        results_list.clear()

        results = [json.loads(i) for i in output if i]
        if results:
            for pkg in results:
                assert isinstance(pkg, dict)
                package_name = pkg.get("package_pname", "Unknown")
                package_desc = pkg.get("package_description", "No description available.")
                display_text = f"{package_name}: {package_desc}"

                # Add to ListView
                results_list.append(LabelItem(display_text))

                # Add to backend list
                self.pkg_list.append(pkg["package_pname"])
            
            self.query_one("#add_button").disabled = False
            self.screen.focus_next(selector="#results_list")
            results_list.children[0].focus()

            self.log_widget.write_line("Packages found!")
        else:
            self.query_one("#add_button").disabled = True
            

    async def action_add_selected(self) -> None:
        """Handle adding a selected package."""
        results_list = self.query_one("#results_list")
        selected = results_list.highlighted_child
        self.log(selected)

        if selected is None:
            raise Exception("nuh uh")  # No package selected
        
        ensure_autohm_imports(HM_FILEPATH, AUTO_HM_FILEPATH)
        ensure_autohm_file(AUTO_HM_FILEPATH)
        self.log_widget.write_line(f"Writing package {selected.label.split(':')[0]} to {AUTO_HM_FILEPATH}")
        write_status = add_package_to_autohm(AUTO_HM_FILEPATH, selected.label.split(":")[0])
        if write_status:
            self.log_widget.write_line(write_status)
        results_list.clear()
        self.log_widget.write_line("Done writing package.")

    async def action_handle_enter(self) -> None:
        "Handle enter key pressed"
        if self.screen.focused == self.query_one('#results_list'):
            await self.action_add_selected()
        elif self.screen.focused == self.query_one('#package_input'):
            await self.action_search()

if __name__ == "__main__":
    app = NixPackageSearchTUI()
    app.run()
    subprocess.check_output(["nix","run", "home-manager", "--", "--flake", "~/remote/.home-manager", "switch"])