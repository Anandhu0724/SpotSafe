export const dynamic = 'force-dynamic'

const NO_STORE_HEADERS = { 'Cache-Control': 'no-store' }
const KERALA_BOUNDS = { minLat: 7.9, maxLat: 12.95, minLng: 74.6, maxLng: 77.5 }
const SEARCH_RADIUS_METERS = 50

type MapillaryImage = {
  id?: string | number
  geometry?: { coordinates?: [number, number] }
  thumb_1024_url?: string
}

type MapillarySearchResponse = { data?: MapillaryImage[] }

const safeThumbnailUrl = (value?: string) => {
  if (!value) return null

  try {
    const url = new URL(value)
    const trustedHost =
      url.hostname === 'mapillary.com' ||
      url.hostname.endsWith('.mapillary.com') ||
      url.hostname.endsWith('.fbcdn.net')

    return url.protocol === 'https:' && trustedHost ? url.toString() : null
  } catch {
    return null
  }
}

const distanceInMeters = (lat1: number, lng1: number, lat2: number, lng2: number) => {
  const radians = (degrees: number) => (degrees * Math.PI) / 180
  const latitudeDelta = radians(lat2 - lat1)
  const longitudeDelta = radians(lng2 - lng1)
  const a =
    Math.sin(latitudeDelta / 2) ** 2 +
    Math.cos(radians(lat1)) *
      Math.cos(radians(lat2)) *
      Math.sin(longitudeDelta / 2) ** 2

  return 6_371_008.8 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

export async function GET(request: Request) {
  const token = process.env.MAPILLARY_ACCESS_TOKEN?.trim()

  if (!token) {
    return Response.json(
      { error: 'Mapillary imagery is not configured.' },
      { status: 503, headers: NO_STORE_HEADERS },
    )
  }

  const searchParams = new URL(request.url).searchParams
  const latitudeParam = searchParams.get('lat')
  const longitudeParam = searchParams.get('lng')
  const latitude = Number(latitudeParam)
  const longitude = Number(longitudeParam)

  if (
    latitudeParam === null ||
    longitudeParam === null ||
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < KERALA_BOUNDS.minLat ||
    latitude > KERALA_BOUNDS.maxLat ||
    longitude < KERALA_BOUNDS.minLng ||
    longitude > KERALA_BOUNDS.maxLng
  ) {
    return Response.json(
      { error: 'Choose a location within Kerala.' },
      { status: 400, headers: NO_STORE_HEADERS },
    )
  }

  const apiUrl = new URL('https://graph.mapillary.com/images')
  apiUrl.searchParams.set('lat', String(latitude))
  apiUrl.searchParams.set('lng', String(longitude))
  apiUrl.searchParams.set('radius', String(SEARCH_RADIUS_METERS))
  apiUrl.searchParams.set('limit', '25')
  apiUrl.searchParams.set('fields', 'id,geometry,thumb_1024_url')

  let apiResponse: Response

  try {
    apiResponse = await fetch(apiUrl, {
      headers: { Authorization: `OAuth ${token}` },
      cache: 'no-store',
      signal: AbortSignal.timeout(10_000),
    })
  } catch {
    return Response.json(
      { error: 'Mapillary imagery is temporarily unavailable.' },
      { status: 502, headers: NO_STORE_HEADERS },
    )
  }

  if (!apiResponse.ok) {
    return Response.json(
      { error: 'Mapillary imagery is temporarily unavailable.' },
      { status: 502, headers: NO_STORE_HEADERS },
    )
  }

  let payload: MapillarySearchResponse

  try {
    payload = (await apiResponse.json()) as MapillarySearchResponse
  } catch {
    return Response.json(
      { error: 'Mapillary imagery is temporarily unavailable.' },
      { status: 502, headers: NO_STORE_HEADERS },
    )
  }

  const nearestImage = (payload.data ?? [])
    .flatMap((image) => {
      const coordinates = image.geometry?.coordinates
      const imageId = image.id

      if (
        imageId === undefined ||
        !coordinates ||
        coordinates.length < 2 ||
        !Number.isFinite(coordinates[0]) ||
        !Number.isFinite(coordinates[1])
      ) {
        return []
      }

      return [
        {
          id: String(imageId),
          distance: distanceInMeters(latitude, longitude, coordinates[1], coordinates[0]),
          thumbnailUrl: image.thumb_1024_url,
        },
      ]
    })
    .sort((first, second) => first.distance - second.distance)[0]

  if (!nearestImage) {
    return Response.json({ found: false }, { headers: NO_STORE_HEADERS })
  }

  return Response.json(
    {
      found: true,
      imageId: nearestImage.id,
      distanceMeters: Math.round(nearestImage.distance),
      thumbnailUrl: safeThumbnailUrl(nearestImage.thumbnailUrl),
    },
    { headers: NO_STORE_HEADERS },
  )
}
