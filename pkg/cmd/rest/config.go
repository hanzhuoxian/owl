package rest

import (
	"fmt"
	"time"

	"github.com/hanzhuoxian/owl/pkg/negotiate"
	"github.com/hanzhuoxian/owl/pkg/scheme"
)

// TLSClientConfig contains settings to enable transport layer security.
type TLSClientConfig struct {
	// Server should be accessed without verifying the TLS certificate. For testing only.
	Insecure bool
	// ServerName is passed to the server for SNI and is used in the client to check server
	// ceritificates against. If ServerName is empty, the hostname used to contact the
	// server is used.
	ServerName string

	// Server requires TLS client certificate authentication
	CertFile string
	// Server requires TLS client certificate authentication
	KeyFile string
	// Trusted root certificates for server
	CAFile string

	// CertData holds PEM-encoded bytes (typically read from a client certificate file).
	// CertData takes precedence over CertFile
	CertData []byte
	// KeyData holds PEM-encoded bytes (typically read from a client certificate key file).
	// KeyData takes precedence over KeyFile
	KeyData []byte
	// CAData holds PEM-encoded bytes (typically read from a root certificates bundle).
	// CAData takes precedence over CAFile
	CAData []byte

	// NextProtos is a list of supported application level protocols, in order of preference.
	// Used to populate tls.Config.NextProtos.
	// To indicate to the server http/1.1 is preferred over http/2, set to ["http/1.1", "h2"] (though the server is free
	// to ignore that preference).
	// To use only http/1.1, set to ["http/1.1"].
	NextProtos []string
}

// ContentConfig contains information about how to communicate with a server.
type ContentConfig struct {
	ServiceName        string
	AcceptContentTypes string
	ContentType        string
	GroupVersion       *scheme.GroupVersion
	Negotiator         negotiate.ClientNegotiator
}

// Config defines a config struct
type Config struct {
	Host    string
	APIPath string
	ContentConfig

	Username string
	Password string

	SecretID  string
	SecretKey string

	BearerToken     string
	BearerTokenFile string

	TLSClientConfig

	UserAgent     string
	Timeout       time.Duration
	MaxRetries    int
	RetryInterval time.Duration
}

type sanitizedConfig *Config

// CopyConfig returns a copy of the given config.
func CopyConfig(config *Config) *Config {
	return &Config{
		Host:            config.Host,
		APIPath:         config.APIPath,
		ContentConfig:   config.ContentConfig,
		Username:        config.Username,
		Password:        config.Password,
		SecretID:        config.SecretID,
		SecretKey:       config.SecretKey,
		BearerToken:     config.BearerToken,
		BearerTokenFile: config.BearerTokenFile,
		TLSClientConfig: TLSClientConfig{
			Insecure:   config.TLSClientConfig.Insecure,
			ServerName: config.TLSClientConfig.ServerName,
			CertFile:   config.TLSClientConfig.CertFile,
			KeyFile:    config.TLSClientConfig.KeyFile,
			CAFile:     config.TLSClientConfig.CAFile,
			CertData:   config.TLSClientConfig.CertData,
			KeyData:    config.TLSClientConfig.KeyData,
			CAData:     config.TLSClientConfig.CAData,
			NextProtos: config.TLSClientConfig.NextProtos,
		},
		UserAgent: config.UserAgent,
		Timeout:   config.Timeout,
	}
}

func (c *Config) String() string {
	if c == nil {
		return "<nil>"
	}

	cc := sanitizedConfig(CopyConfig(c))
	// Explicitly mark non-empty credential fields as redacted.
	if cc.Password != "" {
		cc.Password = "--- REDACTED ---"
	}

	if cc.BearerToken != "" {
		cc.BearerToken = "--- REDACTED ---"
	}

	if cc.SecretKey != "" {
		cc.SecretKey = "--- REDACTED ---"
	}

	return fmt.Sprintf("%#v", cc)
}

func (c *Config) GoString() string {
	return c.String()
}

var (
	_ fmt.Stringer   = TLSClientConfig{}
	_ fmt.GoStringer = TLSClientConfig{}
)

type sanitizedTLSClientConfig TLSClientConfig

func (c TLSClientConfig) GoString() string {
	return c.String()
}

func (c TLSClientConfig) String() string {
	cc := sanitizedTLSClientConfig(c)
	// Explicitly mark non-empty credential fields as redacted.
	if len(cc.CertData) != 0 {
		cc.CertData = []byte("--- TRUNCATED ---")
	}

	if len(cc.KeyData) != 0 {
		cc.KeyData = []byte("--- REDACTED ---")
	}

	return fmt.Sprintf("%#v", cc)
}

// HasCA returns true if the client is using a CA for TLS verification.
func (c TLSClientConfig) HasCA() bool {
	return len(c.CAData) > 0 || len(c.CAFile) > 0
}

// HasCertAuth returns true if the client is using a client certificate for authentication.
func (c TLSClientConfig) HasCertAuth() bool {
	return (len(c.CertData) != 0 || len(c.CertFile) != 0) && (len(c.KeyData) != 0 || len(c.KeyFile) != 0)
}

func RESTClientFor(config *Config) (*RESTClient, error) {
	return newRESTClient(config)
}
