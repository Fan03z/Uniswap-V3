import * as SanityClient from "@sanity/client";

const { createClient } = SanityClient;

export const client = createClient({
  projectId: "d19rn05h",
  dataset: "production",
  apiVersion: "v1",
  token:
    "sk5TdSZlvPMOxAoOcdY9YesKsEjZeVtZMHSOyXm0Z12wCdPwhXgCcfPOatBFVTp4PT40Ey4iO07wFEH2lIJwkNU4AJmAisE8wMV0Fk1IjgiOYRpXGyJHs84qMV2jBO44xm6iIGiRWU94eIobpOOomhaUqyxtt09piV3rTSUykDd3IEQMQO9n",
  useCdn: false,
});
