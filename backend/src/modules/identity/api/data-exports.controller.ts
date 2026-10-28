import { Controller, Get, Header, Param, Res } from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import type { Response } from "express";
import { DataExportService } from "../internal/profile/data-export.service";
import { DataExportTokenDto } from "./user-dto/data-export-token.dto";

/**
 * D63 (w40): the one download of an account's own data. No session: the
 * link's random token is the credential, it works once and expires in
 * fifteen minutes, so the phone opens it in its browser.
 */
@Controller("api/v1/data-exports")
export class DataExportsController {
  constructor(private readonly dataExports: DataExportService) {}

  @Get(":token")
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  @Header("Cache-Control", "private, no-store")
  @Header("Referrer-Policy", "no-referrer")
  async download(
    @Param() params: DataExportTokenDto,
    @Res({ passthrough: true }) response: Response,
  ) {
    const file = await this.dataExports.download(params.token);
    response.setHeader(
      "Content-Disposition",
      `attachment; filename="${file.fileName}"`,
    );
    return file.body;
  }
}
