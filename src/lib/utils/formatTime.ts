/**
 * Formats minutes into a human-readable hours and minutes string
 * @param minutes - Total minutes to format
 * @returns Formatted string like "2h 30m" or "45m"
 */
export function formatMinutes(minutes: number): string {
    if (minutes < 60) {
        return `${minutes} min`
    }

    const hours = Math.floor(minutes / 60)
    const remainingMinutes = minutes % 60

    if (remainingMinutes === 0) {
        return `${hours}h`
    }

    return `${hours}h ${remainingMinutes}m`
}

/**
 * Formats minutes into a short format for charts/badges
 * @param minutes - Total minutes to format
 * @returns Short formatted string like "2h 30m" or "45m"
 */
export function formatMinutesShort(minutes: number): string {
    if (minutes < 60) {
        return `${minutes}m`
    }

    const hours = Math.floor(minutes / 60)
    const remainingMinutes = minutes % 60

    if (remainingMinutes === 0) {
        return `${hours}h`
    }

    return `${hours}h ${remainingMinutes}m`
}
