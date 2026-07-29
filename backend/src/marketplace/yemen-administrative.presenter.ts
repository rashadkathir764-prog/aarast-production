import type { District, Governorate } from "@prisma/client";

export class YemenAdministrativePresenter {
  private constructor() {}

  static toGovernorateResponse(
    governorate: Governorate & { _count?: { districts: number } },
  ) {
    return {
      id: governorate.id,
      code: governorate.code,
      nameAr: governorate.nameAr,
      nameEn: governorate.nameEn,
      latitude: governorate.latitude,
      longitude: governorate.longitude,
      sortOrder: governorate.sortOrder,
      districtsCount: governorate._count?.districts,
    };
  }

  static toDistrictResponse(district: District) {
    return {
      id: district.id,
      governorateId: district.governorateId,
      code: district.code,
      nameAr: district.nameAr,
      nameEn: district.nameEn,
      latitude: district.latitude,
      longitude: district.longitude,
      sortOrder: district.sortOrder,
    };
  }
}
