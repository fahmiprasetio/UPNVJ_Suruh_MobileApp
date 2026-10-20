namespace UpnvjSuruh.Api.Contracts;

public sealed record PerbaruiLokasiRunnerRequest(
    double Latitude,
    double Longitude,
    double? AkurasiMeter,
    double? ArahDerajat,
    double? KecepatanMeterPerDetik,
    DateTime DirekamPada);

public sealed record LokasiRunnerResponse(
    Guid OrderId,
    Guid RunnerId,
    double Latitude,
    double Longitude,
    double? AkurasiMeter,
    double? ArahDerajat,
    double? KecepatanMeterPerDetik,
    DateTime DirekamPada,
    DateTime DiterimaPada);
