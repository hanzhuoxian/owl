package main

import (
	"os"

	"github.com/hanzhuoxian/owl/internal/owlctl/cmd"
)

func main() {
	command := cmd.NewDefaultOwlCtlCommand()
	if err := command.Execute(); err != nil {
		os.Exit(1)
	}
}
