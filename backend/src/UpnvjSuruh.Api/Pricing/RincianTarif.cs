namespace UpnvjSuruh.Api.Pricing;

public record RincianTarif(string Label, decimal Nominal);

public record HasilTarif(IReadOnlyList<RincianTarif> Rincian, decimal Total);
