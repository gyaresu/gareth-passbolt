package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

/*
The "bulk" set is generated rather than read from datasets/, because a vault big
enough to be worth measuring is several megabytes of JSON and has no business
being committed. The other sets are hand-authored and small; this one exists to
make the stack slow on purpose.

It is for reproducing large-vault behaviour locally: cold-start login time, the
client-side decrypt and local-storage write, and list rendering. Those costs scale
with resource count, and a 48-entry demo vault cannot show them.

Content is deliberately uniform and dull. The point is the count and the size of
the encrypted metadata, not the words.
*/

// bulkDatasetName is the DATASET value that selects the generated set rather than
// a file under datasets/.
const bulkDatasetName = "bulk"

const bulkDescription = "Service account used by the %s tier in %s. Credentials are rotated on the " +
	"standard quarterly schedule and are referenced by the deployment pipeline rather than entered " +
	"by hand. Region %s. Escalate to the platform team before changing scope, since several " +
	"downstream jobs authenticate with this same principal and will fail closed if it is revoked " +
	"without notice."

var (
	bulkSystems = []string{"Atlas", "Borealis", "Cobalt", "Dynamo", "Everest", "Fathom", "Granite",
		"Harbour", "Ionic", "Juniper", "Kestrel", "Lumen", "Meridian", "Nimbus", "Onyx",
		"Pinnacle", "Quarry", "Rampart", "Summit", "Tundra"}
	bulkRoles = []string{"api", "admin", "backup", "ci", "db", "deploy", "metrics", "monitor",
		"proxy", "queue", "registry", "replica", "scheduler", "storage", "worker"}
	bulkEnvs    = []string{"prod", "staging", "uat", "dev", "dr"}
	bulkRegions = []string{"ap-southeast-2", "eu-west-1", "us-east-1", "ap-south-1"}
)

// envInt reads an integer environment variable, falling back to def when unset,
// unparseable, or not positive.
func envInt(key string, def int) int {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil || n <= 0 {
		return def
	}
	return n
}

// bulkShareGroups is the default set of groups to share with when sharing is
// enabled. Groups that do not exist on the instance are warned about and skipped.
var bulkShareGroups = []string{"developers", "demoteam"}

// generateBulk builds a seed set of count resources spread over a folder tree.
//
// Everything is derived from the index, so a given count always produces the same
// vault and two runs can be compared. Nothing is starred or given a TOTP, and by
// default nothing is shared either, because each of those adds work per resource
// and these runs are long enough already.
//
// BULK_SHARE_PCT (0 to 100, default 0) shares that percentage of resources with
// BULK_SHARE_GROUPS. Turn it on when the thing under test involves a user who is
// not the owner, or the server-side permission lookup. Leave it off when testing
// the owner's own cold-start login, where sharing changes little: with shared
// metadata keys the metadata is encrypted to the same key either way, and the
// logging-in user still gets one permission record per resource.
//
// Be deliberate about enabling it. A share re-encrypts the secret to every
// recipient's key and costs an extra API call per resource, so a five-figure run
// goes from slow to very slow.
func generateBulk(count int) seedData {
	folders := make([]folderSpec, 0, len(bulkSystems)*(len(bulkEnvs)+1))
	for _, s := range bulkSystems {
		folders = append(folders, folderSpec{Path: s})
		for _, e := range bulkEnvs {
			folders = append(folders, folderSpec{Path: s + "/" + e})
		}
	}

	sharePct := envInt("BULK_SHARE_PCT", 0)
	if sharePct > 100 {
		sharePct = 100
	}

	resources := make([]resourceSpec, 0, count)
	for i := range count {
		// Mixed-radix: environment is the fastest digit, so every system/environment
		// folder is reached within each run of 100, whatever the count. Driving two
		// axes off i directly welds them together whenever one length divides the
		// other, which left 100 of the 120 folders empty.
		environment := bulkEnvs[i%len(bulkEnvs)]
		system := bulkSystems[(i/len(bulkEnvs))%len(bulkSystems)]
		role := bulkRoles[(i/(len(bulkEnvs)*len(bulkSystems)))%len(bulkRoles)]
		region := bulkRegions[i%len(bulkRegions)]

		resources = append(resources, resourceSpec{
			Name:        fmt.Sprintf("%s %s %s %05d", system, role, environment, i),
			Username:    fmt.Sprintf("svc_%s_%s_%05d", role, environment, i),
			URI:         fmt.Sprintf("https://%s-%05d.%s.%s.internal.example", role, i, lower(system), environment),
			Folder:      system + "/" + environment,
			Description: fmt.Sprintf(bulkDescription, role, environment, region),
			Icon:        i % 69,
			// Spread the hue across the index so the list is not a wall of one colour.
			Color: fmt.Sprintf("#%02X%02X%02X", (i*37)%256, (i*91)%256, (i*53)%256),
			// Evenly spread rather than the first N, so any slice of the vault has
			// roughly the same mix of shared and private.
			Shared: sharePct > 0 && i%100 < sharePct,
		})
	}

	data := seedData{
		Owner:     env("BULK_OWNER", "ada@passbolt.com"),
		Folders:   folders,
		Resources: resources,
	}
	if sharePct > 0 {
		data.ShareGroups = splitList(env("BULK_SHARE_GROUPS", strings.Join(bulkShareGroups, ",")))
	}
	return data
}

// runDeadline sizes the overall timeout to the work in the set rather than using a
// fixed value. A flat ten minutes is plenty for a 48-entry demo set and nowhere near
// enough for a five-figure one: every resource is a create with client-side
// encryption, and every shared resource adds a re-encrypt to each recipient's key on
// top. Getting killed partway leaves a half-populated vault, which is worse than
// waiting.
//
// TIMEOUT_MINUTES overrides it outright when you want a hard ceiling.
func runDeadline(data seedData) time.Duration {
	if m := envInt("TIMEOUT_MINUTES", 0); m > 0 {
		return time.Duration(m) * time.Minute
	}

	shared := 0
	for _, r := range data.Resources {
		if r.Shared || len(r.ShareUsers) > 0 {
			shared++
		}
	}

	// Measured on a local stack at the default four workers: 74 resources a second
	// unshared, 34 at 20% shared. These allowances are an order of magnitude above
	// that on purpose. Throughput depends on the host and on how loaded the server
	// is, and a ceiling only costs something when it is actually hit.
	d := 10*time.Minute +
		time.Duration(len(data.Resources))*500*time.Millisecond +
		time.Duration(shared)*time.Second
	return d
}

// splitList parses a comma-separated env value, dropping blanks and surrounding space.
func splitList(s string) []string {
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

func lower(s string) string {
	b := []byte(s)
	for i := range b {
		if b[i] >= 'A' && b[i] <= 'Z' {
			b[i] += 'a' - 'A'
		}
	}
	return string(b)
}
