package spec_test

import (
	"path/filepath"
	"runtime"

	. "github.com/genesis-community/testkit/v2/testing"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = BeforeSuite(func() {
	_, filename, _, _ := runtime.Caller(0)
	KitDir, _ = filepath.Abs(filepath.Join(filepath.Dir(filename), "../"))
})

var _ = Describe("minio Kit", func() {

	Describe("minio", func() {
		Test(Environment{
			Name:        "base",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		Test(Environment{
			Name:        "distributed",
			CloudConfig: "aws",
			CPI:         "aws",
		})
		// Genesis wraps long messages to the terminal width, so the matcher
		// accepts any whitespace between the words.
		Test(Environment{
			Name:        "distributed-odd-nodes",
			CloudConfig: "aws",
			CPI:         "aws",
			OutputMatchers: OutputMatchers{
				GenesisAddSecrets: MatchRegexp(`an\s+even\s+number\s+from\s+4\s+to\s+32`),
				GenesisCheck:      MatchRegexp(`an\s+even\s+number\s+from\s+4\s+to\s+32`),
				GenesisManifest:   MatchRegexp(`an\s+even\s+number\s+from\s+4\s+to\s+32`),
			},
		})
	})
})
