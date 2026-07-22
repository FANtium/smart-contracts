#!/usr/bin/env bun
/**
 * Generates `test/fixtures/phase-seeds.json`: the multi-phase price schedules injected on-chain by
 * `FANtiumAthletesV12.initializeV12(seeds)` during the V11 -> V12 upgrade.
 *
 * Source of truth is the Strapi `nft` content type (one entry per on-chain collection), whose
 * `discountSection` component holds the three-tranche schedule that is currently enforced
 * off-chain (EarlyBird -> Initial -> Regular, each with a token amount and a whole-USDC price).
 * Collections without a complete discount section are skipped: they keep the single-phase
 * migration derived from their on-chain legacy price.
 *
 * The output is sorted by collection ID and its object keys are alphabetically ordered so that
 * Foundry's `vm.parseJson` can decode it (see `UpgradeMainnetV12.s.sol` and
 * `UpgradeMainnetV12.fork.t.sol`).
 *
 * Usage (from the repo root, where `.env` provides STRAPI_GRAPHQL_URL and STRAPI_TOKEN):
 *   bun contracts/fantium-v1/scripts/generatePhaseSeeds.ts
 */

type DiscountSection = {
	tokenAmountEarlyBird: number;
	tokenAmountInitial: number;
	tokenAmountRegular: number;
	priceEarlyBird: number;
	priceInitial: number;
	priceRegular: number;
};

type StrapiNft = {
	collectionID: string;
	title: string | null;
	discountSection: DiscountSection | null;
};

type PhaseJson = {
	maxInvocations: number;
	price: number;
};

type PhaseSeedJson = {
	collectionId: number;
	phases: PhaseJson[];
};

const STRAPI_GRAPHQL_URL = process.env.STRAPI_GRAPHQL_URL;
const STRAPI_TOKEN = process.env.STRAPI_TOKEN;

if (!STRAPI_GRAPHQL_URL || !STRAPI_TOKEN) {
	console.error('Missing STRAPI_GRAPHQL_URL or STRAPI_TOKEN; run from the repo root so .env is loaded.');
	process.exit(1);
}

const query = /* GraphQL */ `
	query PhaseSeeds {
		nfts(pagination: { limit: 500 }) {
			collectionID
			title
			discountSection {
				tokenAmountEarlyBird
				tokenAmountInitial
				tokenAmountRegular
				priceEarlyBird
				priceInitial
				priceRegular
			}
		}
	}
`;

const response = await fetch(STRAPI_GRAPHQL_URL, {
	method: 'POST',
	headers: {
		Authorization: `Bearer ${STRAPI_TOKEN}`,
		'Content-Type': 'application/json',
	},
	body: JSON.stringify({ query }),
});

if (!response.ok) {
	console.error(`Strapi request failed: ${response.status} ${response.statusText}`);
	process.exit(1);
}

const { data, errors } = (await response.json()) as { data?: { nfts: StrapiNft[] }; errors?: unknown };
if (errors || !data) {
	console.error('Strapi GraphQL errors:', JSON.stringify(errors));
	process.exit(1);
}

const seeds: PhaseSeedJson[] = [];
const skipped: string[] = [];

for (const nft of data.nfts) {
	const collectionId = Number.parseInt(nft.collectionID, 10);
	const label = `#${nft.collectionID} (${nft.title ?? 'untitled'})`;
	const d = nft.discountSection;

	if (!d) {
		continue; // no discount schedule: single-phase migration from the on-chain legacy price
	}

	const fields = [
		d.tokenAmountEarlyBird,
		d.priceEarlyBird,
		d.tokenAmountInitial,
		d.priceInitial,
		d.tokenAmountRegular,
		d.priceRegular,
	];
	if (fields.some((value) => !Number.isInteger(value) || value <= 0)) {
		// Same completeness gate as the frontend (DiscountPricing): partial sections are display-only noise.
		skipped.push(`${label}: incomplete discount section (${JSON.stringify(d)})`);
		continue;
	}

	seeds.push({
		collectionId,
		phases: [
			{ maxInvocations: d.tokenAmountEarlyBird, price: d.priceEarlyBird },
			{ maxInvocations: d.tokenAmountInitial, price: d.priceInitial },
			{ maxInvocations: d.tokenAmountRegular, price: d.priceRegular },
		],
	});
}

seeds.sort((a, b) => a.collectionId - b.collectionId);

const duplicates = seeds.filter((seed, i) => i > 0 && seeds[i - 1].collectionId === seed.collectionId);
if (duplicates.length > 0) {
	console.error(`Duplicate collection ids in Strapi: ${duplicates.map((seed) => seed.collectionId).join(', ')}`);
	process.exit(1);
}

const outputPath = new URL('../test/fixtures/phase-seeds.json', import.meta.url).pathname;
await Bun.write(outputPath, `${JSON.stringify(seeds, null, '\t')}\n`);

console.log(`Wrote ${seeds.length} phase seeds to ${outputPath}`);
for (const seed of seeds) {
	const total = seed.phases.reduce((sum, phase) => sum + phase.maxInvocations, 0);
	const schedule = seed.phases.map((phase) => `${phase.maxInvocations}@$${phase.price}`).join(' -> ');
	console.log(`  collection ${seed.collectionId}: ${schedule} (total supply ${total})`);
}
if (skipped.length > 0) {
	console.log('Skipped (kept single-phase):');
	for (const line of skipped) {
		console.log(`  ${line}`);
	}
}
