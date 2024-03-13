package cmd

import (
	"fmt"
	"os"
	"runtime"
	"runtime/pprof"

	"github.com/spf13/pflag"
)

const (
	profileNameNone         = "none"
	profileNameCpu          = "cpu"
	profileNameHeap         = "heap"
	profileNameGoroutine    = "goroutine"
	profileNameThreadCreate = "threadcreate"
	profileNameBlock        = "block"
	profileNameMutex        = "mutex"
)

var (
	profileName   string
	profileOutput string
)

func addProfilingFlags(flags *pflag.FlagSet) {
	flags.StringVar(&profileName,
		"profile",
		profileNameNone,
		"Name of profile to capture. One of (none|cpu|heap|goroutine|threadcreate|block|mutex)",
	)
	flags.StringVar(&profileOutput, "profile-output", "profile.pprof", "Name of the file to write the profile to")
}

func initProfiling() error {
	switch profileName {
	case profileNameNone:
		return nil
	case profileNameCpu:
		f, err := os.Create(profileOutput)
		if err != nil {
			return err
		}

		return pprof.StartCPUProfile(f)
	case profileNameBlock:
		runtime.SetBlockProfileRate(1)

		return nil
	case profileNameMutex:
		runtime.SetMutexProfileFraction(1)

		return nil
	default:
		if profile := pprof.Lookup(profileName); profile == nil {
			return fmt.Errorf("unknown profile '%s'", profileName)
		}
	}

	return nil
}

func flushProfiling() error {
	switch profileName {
	case profileNameNone:
		return nil
	case profileNameCpu:
		pprof.StopCPUProfile()
	case profileNameHeap:
		runtime.GC()

		fallthrough
	default:
		profile := pprof.Lookup(profileName)
		if profile == nil {
			return nil
		}
		f, err := os.Create(profileOutput)
		if err != nil {
			return err
		}
		_ = profile.WriteTo(f, 0)
	}

	return nil
}
