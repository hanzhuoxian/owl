package options

import (
	"sync"
	"time"

	"github.com/spf13/viper"
)

// Defines flag for owlctl.
const (
	FlagConfig        = "config"
	FlagBearerToken   = "user.token"
	FlagUsername      = "user.username"
	FlagPassword      = "user.password"
	FlagSecretID      = "user.secret-id"
	FlagSecretKey     = "user.secret-key"
	FlagCertFile      = "user.client-certificate"
	FlagKeyFile       = "user.client-key"
	FlagTLSServerName = "server.tls-server-name"
	FlagInsecure      = "server.insecure-skip-tls-verify"
	FlagCAFile        = "server.certificate-authority"
	FlagAPIServer     = "server.address"
	FlagTimeout       = "server.timeout"
	FlagMaxRetries    = "server.max-retries"
	FlagRetryInterval = "server.retry-interval"
)

// Config holds the common attributes that can be passed to a IAM client on
// initialization.
type Config struct {
	Host    string
	APIPath string
	ContentConfig

	// Server requires Basic authentication
	Username string
	Password string

	SecretID  string
	SecretKey string

	// Server requires Bearer authentication. This client will not attempt to use
	// refresh tokens for an OAuth2 flow.
	BearerToken string

	// Path to a file containing a BearerToken.
	// If set, the contents are periodically read.
	// The last successfully read value takes precedence over BearerToken.
	BearerTokenFile string

	// TLSClientConfig contains settings to enable transport layer security
	TLSClientConfig

	// UserAgent is an optional field that specifies the caller of this request.
	UserAgent string
	// The maximum length of time to wait before giving up on a server request. A value of zero means no timeout.
	Timeout       time.Duration
	MaxRetries    int
	RetryInterval time.Duration
}

// ContentConfig defines config for content.
type ContentConfig struct {
	ServiceName        string
	AcceptContentTypes string
	ContentType        string
}

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

type RESTClientGetter interface {
	ToRESTConfig() (*Config, error)
	ToRowConfigLoader()
}

var _ RESTClientGetter = &ConfigFlags{}

// ClientConfig is used to make it easy to get an api server client.
type ClientConfig interface {
	// ClientConfig returns a complete client config
	ClientConfig() (*Config, error)
}

// ConfigFlags composes the set of values necessary
// for obtaining a REST client config.
type ConfigFlags struct {
	Config *string

	BearerToken *string
	Username    *string
	Password    *string
	SecretID    *string
	SecretKey   *string

	Insecure      *bool
	TLSServerName *string
	CertFile      *string
	KeyFile       *string
	CAFile        *string

	APIServer     *string
	Timeout       *time.Duration
	MaxRetries    *int
	RetryInterval *time.Duration

	clientConfig ClientConfig
	lock         sync.Mutex
	// If set to true, will use persistent client config and
	// propagate the config to the places that need it, rather than
	// loading the config multiple times
	usePersistentConfig bool
}

func (f *ConfigFlags) ToRESTConfig() (*Config, error) {
	return f.ToRowConfigLoader().ClientConfig()
}

func (f *ConfigFlags) ToRawConfigLoader() ClientConfig {
	if f.usePersistentConfig {
		return f.toRawPersistentConfigLoader()
	}

	return f.toRawConfigLoader()
}

func (f *ConfigFlags) toRawConfigLoader() ClientConfig {
	config := NewConfig()
	if err := viper.Unmarshal(&config); err != nil {
		panic(err)
	}

	return NewClientConfigFromConfig(config)
}

func NewConfig() {

}
