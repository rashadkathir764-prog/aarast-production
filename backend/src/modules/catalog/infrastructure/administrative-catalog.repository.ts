import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

type Client = Prisma.TransactionClient;

@Injectable()
export class AdministrativeCatalogRepository {
  listGovernorates(client: Client) {
    return client.governorate.findMany({
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      include: { _count: { select: { districts: true } } },
    });
  }

  listDistricts(client: Client, governorateId: string) {
    return client.district.findMany({
      where: { governorateId },
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      include: { _count: { select: { localities: true } } },
    });
  }

  listLocalities(client: Client, districtId: string) {
    return client.administrativeLocality.findMany({
      where: { districtId },
      orderBy: [{ type: 'asc' }, { sortOrder: 'asc' }, { nameAr: 'asc' }],
    });
  }

  findActiveDistrictWithGovernorate(client: Client, districtId: string) {
    return client.district.findFirst({
      where: {
        id: districtId,
        isActive: true,
        governorate: { isActive: true },
      },
      select: { id: true },
    });
  }

  listActiveLocalities(client: Client, districtId: string) {
    return client.administrativeLocality.findMany({
      where: { districtId, isActive: true },
      orderBy: [{ type: 'asc' }, { sortOrder: 'asc' }, { nameAr: 'asc' }],
      select: {
        id: true,
        districtId: true,
        parentId: true,
        code: true,
        type: true,
        nameAr: true,
        nameEn: true,
        latitude: true,
        longitude: true,
        sortOrder: true,
      },
    });
  }

  createGovernorate(tx: Client, data: Prisma.GovernorateUncheckedCreateInput) {
    return tx.governorate.create({ data: {
      code: data.code,
      nameAr: data.nameAr,
      nameEn: data.nameEn,
      latitude: data.latitude,
      longitude: data.longitude,
      sortOrder: data.sortOrder,
      isActive: data.isActive,
    } });
  }

  getGovernorate(tx: Client, id: string) {
    return tx.governorate.findUnique({ where: { id } });
  }

  updateGovernorate(
    tx: Client,
    id: string,
    data: Prisma.GovernorateUncheckedUpdateInput,
  ) {
    return tx.governorate.update({ where: { id }, data: {
      ...(data.nameAr === undefined ? {} : { nameAr: data.nameAr }),
      ...(data.nameEn === undefined ? {} : { nameEn: data.nameEn }),
      ...(data.latitude === undefined ? {} : { latitude: data.latitude }),
      ...(data.longitude === undefined ? {} : { longitude: data.longitude }),
      ...(data.sortOrder === undefined ? {} : { sortOrder: data.sortOrder }),
      ...(data.isActive === undefined ? {} : { isActive: data.isActive }),
    } });
  }

  disableGovernorate(tx: Client, id: string) {
    return tx.governorate.update({ where: { id }, data: { isActive: false } });
  }

  createDistrict(tx: Client, data: Prisma.DistrictUncheckedCreateInput) {
    return tx.district.create({ data: {
      governorateId: data.governorateId,
      code: data.code,
      nameAr: data.nameAr,
      nameEn: data.nameEn,
      latitude: data.latitude,
      longitude: data.longitude,
      sortOrder: data.sortOrder,
      isActive: data.isActive,
    } });
  }

  getDistrict(tx: Client, id: string) {
    return tx.district.findUnique({ where: { id } });
  }

  updateDistrict(tx: Client, id: string, data: Prisma.DistrictUncheckedUpdateInput) {
    return tx.district.update({ where: { id }, data: {
      ...(data.nameAr === undefined ? {} : { nameAr: data.nameAr }),
      ...(data.nameEn === undefined ? {} : { nameEn: data.nameEn }),
      ...(data.latitude === undefined ? {} : { latitude: data.latitude }),
      ...(data.longitude === undefined ? {} : { longitude: data.longitude }),
      ...(data.sortOrder === undefined ? {} : { sortOrder: data.sortOrder }),
      ...(data.isActive === undefined ? {} : { isActive: data.isActive }),
    } });
  }

  disableDistrict(tx: Client, id: string) {
    return tx.district.update({ where: { id }, data: { isActive: false } });
  }

  createLocality(tx: Client, data: Prisma.AdministrativeLocalityUncheckedCreateInput) {
    return tx.administrativeLocality.create({ data: {
      districtId: data.districtId,
      parentId: data.parentId,
      code: data.code,
      type: data.type,
      nameAr: data.nameAr,
      nameEn: data.nameEn,
      latitude: data.latitude,
      longitude: data.longitude,
      sortOrder: data.sortOrder,
      isActive: data.isActive,
    } });
  }

  getLocality(tx: Client, id: string) {
    return tx.administrativeLocality.findUnique({ where: { id } });
  }

  updateLocality(
    tx: Client,
    id: string,
    data: Prisma.AdministrativeLocalityUncheckedUpdateInput,
  ) {
    return tx.administrativeLocality.update({ where: { id }, data: {
      ...(data.nameAr === undefined ? {} : { nameAr: data.nameAr }),
      ...(data.nameEn === undefined ? {} : { nameEn: data.nameEn }),
      ...(data.latitude === undefined ? {} : { latitude: data.latitude }),
      ...(data.longitude === undefined ? {} : { longitude: data.longitude }),
      ...(data.sortOrder === undefined ? {} : { sortOrder: data.sortOrder }),
      ...(data.isActive === undefined ? {} : { isActive: data.isActive }),
      ...(data.type === undefined ? {} : { type: data.type }),
      ...(data.parentId === undefined ? {} : { parentId: data.parentId }),
    } });
  }

  disableLocality(tx: Client, id: string) {
    return tx.administrativeLocality.update({ where: { id }, data: { isActive: false } });
  }

  getLocalityParent(tx: Client, id: string) {
    return tx.administrativeLocality.findUnique({
      where: { id },
      select: { districtId: true, parentId: true },
    });
  }

  async isAdministrativeCodeTaken(tx: Client, code: string): Promise<boolean> {
    const [governorate, district, locality] = await Promise.all([
      tx.governorate.findUnique({ where: { code }, select: { id: true } }),
      tx.district.findUnique({ where: { code }, select: { id: true } }),
      tx.administrativeLocality.findUnique({ where: { code }, select: { id: true } }),
    ]);
    return Boolean(governorate || district || locality);
  }

  findGovernorate(client: Client, id: string, activeOnly: boolean) {
    return client.governorate.findFirst({
      where: { id, ...(activeOnly ? { isActive: true } : {}) },
    });
  }

  findDistrict(client: Client, id: string, activeOnly: boolean) {
    return client.district.findFirst({
      where: { id, ...(activeOnly ? { isActive: true } : {}) },
    });
  }
}
