// Package cmd create a root cobra command and add subcommands to it.
package cmd

import (
	"io"
	"os"

	"github.com/spf13/cobra"
)

func NewDefaultOwlCtlCommand() *cobra.Command {
	return NewOwlCtlCommand(os.Stdin, os.Stdout, os.Stderr)
}

func NewOwlCtlCommand(in io.Reader, out, err io.Writer) *cobra.Command {
	cmds := &cobra.Command{
		Use:   "owlctl",
		Short: "owlctl controls the owl platform",
		Long:  `owlctl controls the owl platform`,
		Run:   runHelp,
	}

	return cmds
}

func runHelp(cmd *cobra.Command, args []string) {
	_ = cmd.Help()
}
