module Presenca
  class SincronizarRegistrosPontoController < ApplicationController
    def create
      unless params[:codAtivacao].present? && %w[poc-ativacao-001 SistemaOperacionalNaoSuportado].include?(params[:codAtivacao])
        return render plain: "sincronizado"
      end

      registros_raw = params[:registros].to_s
      registros_decrypted = decrypt_registros(registros_raw)
      linhas = registros_decrypted.split("\n").map(&:strip).reject(&:empty?)

      linhas.each do |linha|
        parts = linha.match(/\A(\d+)-(\d{2}:\d{2}:\d{4}:\d{2}:\d{2}:\d{2})\z/)
        next unless parts

        user_id = parts[1].to_i
        punched_at = DateTime.strptime(parts[2], "%d:%m:%Y:%H:%M:%S")
        next unless User.exists?(user_id)

        punch_type = begin
          PunchTypeService.determine(user_id, punched_at)
        rescue => e
          Rails.logger.warn "[PunchTypeService] Erro para user #{user_id}: #{e.message}"
          nil
        end

        TimeRecord.create!(
          user_id: user_id,
          raw_data: linha,
          punched_at: punched_at,
          authentication_mode: "biometric",
          punch_type: punch_type
        )
      end

      render plain: "sincronizado"
    rescue
      render plain: "sincronizado"
    end

    private

    def decrypt_registros(raw)
      return raw if raw.blank?

      begin
        CryptoDes.decrypt(raw)
      rescue
        raw
      end
    end
  end
end