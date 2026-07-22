declare module 'area-data' {
  const areaData: {
    pca: Record<string, Record<string, string>>
    pcaa: Record<string, Record<string, string>>
  }

  export const pca: Record<string, Record<string, string>>
  export default areaData
}
