const LOOKBACK_MINUTES = 5;

const ALLOWED_TITLE_PATTERNS = [
  /^.+$/,
  // /end-to-end alerting is unhealthy \(production\)/i,
  // /.*ninesapp\/instances-up-staging is CRITICAL.*/i,
  // /.*failbotg\/fluent-delivery-fast-high-burn-rate-staff-wus2-01 is CRITICAL.*/i,
];

function isIncidentTitleAllowed(title) {
  return ALLOWED_TITLE_PATTERNS.some((pattern) => pattern.test(title));
}

const MY_USER_ID = "P5YP2S3"; // andreykaipov

async function fetchTriggeredIncidents(token) {
  const since = new Date(Date.now() - LOOKBACK_MINUTES * 60 * 1000).toISOString();
  const params = new URLSearchParams({
    "statuses[]": "triggered",
    "user_ids[]": MY_USER_ID,
    since,
    sort_by: "created_at:desc",
    limit: "100",
  });

  const url = `https://api.pagerduty.com/incidents?${params}`;
  console.log(`Fetching triggered incidents since ${since}...`);

  const response = await fetch(url, {
    headers: {
      Authorization: `Token token=${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch incidents: ${response.status} ${await response.text()}`);
  }

  const data = await response.json();
  return data.incidents || [];
}

async function acknowledgeIncidents(token, incidents) {
  const payload = {
    incidents: incidents.map((inc) => ({
      id: inc.id,
      status: "acknowledged",
      type: "incident_reference",
    })),
  };

  console.log(`Acknowledging ${incidents.length} incident(s): ${incidents.map((i) => i.id).join(", ")}`);

  const response = await fetch("https://api.pagerduty.com/incidents", {
    method: "PUT",
    headers: {
      Authorization: `Token token=${token}`,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    throw new Error(`Failed to acknowledge incidents: ${response.status} ${await response.text()}`);
  }

  const data = await response.json();
  console.log(`Successfully acknowledged ${data.incidents?.length ?? 0} incident(s).`);
}

export default server(
  (r) => {
    r.get("/", () => new Response("burnout-baby is running 🔥👶"));
  },
  async (event, env, ctx) => {
    const token = env.PAGERDUTY_TOKEN;
    const incidents = await fetchTriggeredIncidents(token);
    console.log(`Found ${incidents.length} triggered incident(s).`);

    const filtered = incidents.filter((inc) => isIncidentTitleAllowed(inc.title));
    console.log(`${filtered.length} incident(s) match allowed title patterns.`);

    if (filtered.length === 0) {
      console.log("Nothing to acknowledge.");
      return;
    }

    filtered.forEach((inc) => console.log(`  • [${inc.id}] ${inc.title}`));
    await acknowledgeIncidents(token, filtered);
  }
);
