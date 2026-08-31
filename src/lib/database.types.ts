export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      adjustment_category_aliases: {
        Row: {
          alias: string
          category: string
          note: string | null
        }
        Insert: {
          alias: string
          category: string
          note?: string | null
        }
        Update: {
          alias?: string
          category?: string
          note?: string | null
        }
        Relationships: []
      }
      adjustment_category_fuel_types: {
        Row: {
          category: string
          fuel_type_code: string
          note: string | null
        }
        Insert: {
          category: string
          fuel_type_code: string
          note?: string | null
        }
        Update: {
          category?: string
          fuel_type_code?: string
          note?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "adjustment_category_fuel_types_fuel_type_code_fkey"
            columns: ["fuel_type_code"]
            isOneToOne: false
            referencedRelation: "fuel_types"
            referencedColumns: ["code"]
          },
        ]
      }
      adjustment_feed_settings: {
        Row: {
          divergence_threshold: number
          id: boolean
        }
        Insert: {
          divergence_threshold?: number
          id?: boolean
        }
        Update: {
          divergence_threshold?: number
          id?: boolean
        }
        Relationships: []
      }
      adjustment_load_runs: {
        Row: {
          adjustments_recorded: number
          failure_reason: string | null
          finished_at: string | null
          id: string
          note: string | null
          outcome: Database["public"]["Enums"]["adjustment_run_outcome"]
          seq: number
          sources_consulted: string[]
          sources_reached: string[]
          started_at: string
        }
        Insert: {
          adjustments_recorded?: number
          failure_reason?: string | null
          finished_at?: string | null
          id?: string
          note?: string | null
          outcome: Database["public"]["Enums"]["adjustment_run_outcome"]
          seq?: number
          sources_consulted?: string[]
          sources_reached?: string[]
          started_at?: string
        }
        Update: {
          adjustments_recorded?: number
          failure_reason?: string | null
          finished_at?: string | null
          id?: string
          note?: string | null
          outcome?: Database["public"]["Enums"]["adjustment_run_outcome"]
          seq?: number
          sources_consulted?: string[]
          sources_reached?: string[]
          started_at?: string
        }
        Relationships: []
      }
      adjustment_run_conflicts: {
        Row: {
          amount: number
          article_url: string | null
          category: string
          citation_span: string | null
          effective_at: string
          id: string
          published_at: string | null
          run_id: string
          source_code: string
        }
        Insert: {
          amount: number
          article_url?: string | null
          category: string
          citation_span?: string | null
          effective_at: string
          id?: string
          published_at?: string | null
          run_id: string
          source_code: string
        }
        Update: {
          amount?: number
          article_url?: string | null
          category?: string
          citation_span?: string | null
          effective_at?: string
          id?: string
          published_at?: string | null
          run_id?: string
          source_code?: string
        }
        Relationships: [
          {
            foreignKeyName: "adjustment_run_conflicts_run_id_fkey"
            columns: ["run_id"]
            isOneToOne: false
            referencedRelation: "adjustment_load_runs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "adjustment_run_conflicts_source_code_fkey"
            columns: ["source_code"]
            isOneToOne: false
            referencedRelation: "adjustment_sources"
            referencedColumns: ["code"]
          },
        ]
      }
      adjustment_sources: {
        Row: {
          active: boolean
          code: string
          created_at: string
          display_name: string
          feed_url: string
          independence_group: string
          note: string | null
        }
        Insert: {
          active?: boolean
          code: string
          created_at?: string
          display_name: string
          feed_url: string
          independence_group: string
          note?: string | null
        }
        Update: {
          active?: boolean
          code?: string
          created_at?: string
          display_name?: string
          feed_url?: string
          independence_group?: string
          note?: string | null
        }
        Relationships: []
      }
      brand_fuel_products: {
        Row: {
          brand_code: string
          brand_is_retailer: boolean | null
          created_at: string
          fuel_type_code: string
          note: string | null
          product_name: string
          sort_order: number
        }
        Insert: {
          brand_code: string
          brand_is_retailer?: boolean | null
          created_at?: string
          fuel_type_code: string
          note?: string | null
          product_name: string
          sort_order: number
        }
        Update: {
          brand_code?: string
          brand_is_retailer?: boolean | null
          created_at?: string
          fuel_type_code?: string
          note?: string | null
          product_name?: string
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "brand_fuel_products_brand_fkey"
            columns: ["brand_code", "brand_is_retailer"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["code", "is_retailer"]
          },
          {
            foreignKeyName: "brand_fuel_products_fuel_type_code_fkey"
            columns: ["fuel_type_code"]
            isOneToOne: false
            referencedRelation: "fuel_types"
            referencedColumns: ["code"]
          },
        ]
      }
      brand_name_affixes: {
        Row: {
          affix: string
          note: string
        }
        Insert: {
          affix: string
          note: string
        }
        Update: {
          affix?: string
          note?: string
        }
        Relationships: []
      }
      brand_name_rules: {
        Row: {
          brand_code: string
          brand_is_retailer: boolean | null
          created_at: string
          id: string
          note: string
          pattern: string
        }
        Insert: {
          brand_code: string
          brand_is_retailer?: boolean | null
          created_at?: string
          id?: string
          note: string
          pattern: string
        }
        Update: {
          brand_code?: string
          brand_is_retailer?: boolean | null
          created_at?: string
          id?: string
          note?: string
          pattern?: string
        }
        Relationships: [
          {
            foreignKeyName: "brand_name_rules_brand_fkey"
            columns: ["brand_code", "brand_is_retailer"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["code", "is_retailer"]
          },
        ]
      }
      brands: {
        Row: {
          code: string
          created_at: string
          display_name: string
          is_retailer: boolean
          products_review_note: string | null
          products_source_url: string | null
          products_verified_at: string | null
          sort_order: number
        }
        Insert: {
          code: string
          created_at?: string
          display_name: string
          is_retailer?: boolean
          products_review_note?: string | null
          products_source_url?: string | null
          products_verified_at?: string | null
          sort_order: number
        }
        Update: {
          code?: string
          created_at?: string
          display_name?: string
          is_retailer?: boolean
          products_review_note?: string | null
          products_source_url?: string | null
          products_verified_at?: string | null
          sort_order?: number
        }
        Relationships: []
      }
      doe_load_runs: {
        Row: {
          doe_region_code: string
          failure_reason: string | null
          id: string
          period_end: string
          period_label: string
          period_start: string
          recorded_at: string | null
          source_url: string
          started_at: string
          status: Database["public"]["Enums"]["doe_load_run_status"]
        }
        Insert: {
          doe_region_code: string
          failure_reason?: string | null
          id?: string
          period_end: string
          period_label: string
          period_start: string
          recorded_at?: string | null
          source_url: string
          started_at?: string
          status?: Database["public"]["Enums"]["doe_load_run_status"]
        }
        Update: {
          doe_region_code?: string
          failure_reason?: string | null
          id?: string
          period_end?: string
          period_label?: string
          period_start?: string
          recorded_at?: string | null
          source_url?: string
          started_at?: string
          status?: Database["public"]["Enums"]["doe_load_run_status"]
        }
        Relationships: [
          {
            foreignKeyName: "doe_load_runs_doe_region_code_fkey"
            columns: ["doe_region_code"]
            isOneToOne: false
            referencedRelation: "doe_regions"
            referencedColumns: ["code"]
          },
        ]
      }
      doe_locality_reports: {
        Row: {
          doe_source_label: string
          id: string
          run_id: string
          status: Database["public"]["Enums"]["doe_locality_report_status"]
        }
        Insert: {
          doe_source_label: string
          id?: string
          run_id: string
          status: Database["public"]["Enums"]["doe_locality_report_status"]
        }
        Update: {
          doe_source_label?: string
          id?: string
          run_id?: string
          status?: Database["public"]["Enums"]["doe_locality_report_status"]
        }
        Relationships: [
          {
            foreignKeyName: "doe_locality_reports_run_id_fkey"
            columns: ["run_id"]
            isOneToOne: false
            referencedRelation: "doe_load_runs"
            referencedColumns: ["id"]
          },
        ]
      }
      doe_reference_prices: {
        Row: {
          brand_code: string
          brand_presence: Database["public"]["Enums"]["doe_brand_presence"]
          common_price: number | null
          fuel_type_code: string
          id: string
          locality_report_id: string
          max_price: number | null
          min_price: number | null
        }
        Insert: {
          brand_code: string
          brand_presence?: Database["public"]["Enums"]["doe_brand_presence"]
          common_price?: number | null
          fuel_type_code: string
          id?: string
          locality_report_id: string
          max_price?: number | null
          min_price?: number | null
        }
        Update: {
          brand_code?: string
          brand_presence?: Database["public"]["Enums"]["doe_brand_presence"]
          common_price?: number | null
          fuel_type_code?: string
          id?: string
          locality_report_id?: string
          max_price?: number | null
          min_price?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "doe_reference_prices_brand_code_fkey"
            columns: ["brand_code"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "doe_reference_prices_brand_code_fkey"
            columns: ["brand_code"]
            isOneToOne: false
            referencedRelation: "brands_needing_product_review"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "doe_reference_prices_fuel_type_code_fkey"
            columns: ["fuel_type_code"]
            isOneToOne: false
            referencedRelation: "fuel_types"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "doe_reference_prices_locality_report_id_fkey"
            columns: ["locality_report_id"]
            isOneToOne: false
            referencedRelation: "doe_locality_reports"
            referencedColumns: ["id"]
          },
        ]
      }
      doe_regions: {
        Row: {
          code: string
          created_at: string
          index_url: string
          name: string
          resolution_strategy: Database["public"]["Enums"]["doe_resolution_strategy"]
          strategy_notes: string | null
          url_pattern: string
        }
        Insert: {
          code: string
          created_at?: string
          index_url: string
          name: string
          resolution_strategy: Database["public"]["Enums"]["doe_resolution_strategy"]
          strategy_notes?: string | null
          url_pattern: string
        }
        Update: {
          code?: string
          created_at?: string
          index_url?: string
          name?: string
          resolution_strategy?: Database["public"]["Enums"]["doe_resolution_strategy"]
          strategy_notes?: string | null
          url_pattern?: string
        }
        Relationships: []
      }
      fuel_types: {
        Row: {
          code: string
          created_at: string
          display_name: string
          max_plausible: number
          min_plausible: number
          sort_order: number
        }
        Insert: {
          code: string
          created_at?: string
          display_name: string
          max_plausible: number
          min_plausible: number
          sort_order: number
        }
        Update: {
          code?: string
          created_at?: string
          display_name?: string
          max_plausible?: number
          min_plausible?: number
          sort_order?: number
        }
        Relationships: []
      }
      localities: {
        Row: {
          created_at: string
          display_name: string
          doe_region_code: string
          doe_source_label: string
          id: string
          osm_name: string | null
          osm_relation_id: number | null
          province_or_region: string
          proxy_source_display_name: string | null
          sourcing_mode: Database["public"]["Enums"]["locality_sourcing_mode"]
        }
        Insert: {
          created_at?: string
          display_name: string
          doe_region_code: string
          doe_source_label: string
          id?: string
          osm_name?: string | null
          osm_relation_id?: number | null
          province_or_region: string
          proxy_source_display_name?: string | null
          sourcing_mode: Database["public"]["Enums"]["locality_sourcing_mode"]
        }
        Update: {
          created_at?: string
          display_name?: string
          doe_region_code?: string
          doe_source_label?: string
          id?: string
          osm_name?: string | null
          osm_relation_id?: number | null
          province_or_region?: string
          proxy_source_display_name?: string | null
          sourcing_mode?: Database["public"]["Enums"]["locality_sourcing_mode"]
        }
        Relationships: [
          {
            foreignKeyName: "localities_doe_region_code_fkey"
            columns: ["doe_region_code"]
            isOneToOne: false
            referencedRelation: "doe_regions"
            referencedColumns: ["code"]
          },
        ]
      }
      price_adjustment_revisions: {
        Row: {
          adjustment_id: string
          id: string
          reason: string
          revised_at: string
          superseded_amount: number
          superseded_effective_at: string
        }
        Insert: {
          adjustment_id: string
          id?: string
          reason: string
          revised_at?: string
          superseded_amount: number
          superseded_effective_at: string
        }
        Update: {
          adjustment_id?: string
          id?: string
          reason?: string
          revised_at?: string
          superseded_amount?: number
          superseded_effective_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "price_adjustment_revisions_adjustment_id_fkey"
            columns: ["adjustment_id"]
            isOneToOne: false
            referencedRelation: "price_adjustments"
            referencedColumns: ["id"]
          },
        ]
      }
      price_adjustment_sources: {
        Row: {
          adjustment_id: string
          amount_reported: number
          article_url: string | null
          citation_span: string | null
          published_at: string | null
          source_code: string
        }
        Insert: {
          adjustment_id: string
          amount_reported: number
          article_url?: string | null
          citation_span?: string | null
          published_at?: string | null
          source_code: string
        }
        Update: {
          adjustment_id?: string
          amount_reported?: number
          article_url?: string | null
          citation_span?: string | null
          published_at?: string | null
          source_code?: string
        }
        Relationships: [
          {
            foreignKeyName: "price_adjustment_sources_adjustment_id_fkey"
            columns: ["adjustment_id"]
            isOneToOne: false
            referencedRelation: "price_adjustments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "price_adjustment_sources_source_code_fkey"
            columns: ["source_code"]
            isOneToOne: false
            referencedRelation: "adjustment_sources"
            referencedColumns: ["code"]
          },
        ]
      }
      price_adjustments: {
        Row: {
          amount: number
          announced_at: string | null
          effective_at: string
          fuel_type_code: string
          id: string
          recorded_at: string
        }
        Insert: {
          amount: number
          announced_at?: string | null
          effective_at: string
          fuel_type_code: string
          id?: string
          recorded_at?: string
        }
        Update: {
          amount?: number
          announced_at?: string | null
          effective_at?: string
          fuel_type_code?: string
          id?: string
          recorded_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "price_adjustments_fuel_type_code_fkey"
            columns: ["fuel_type_code"]
            isOneToOne: false
            referencedRelation: "fuel_types"
            referencedColumns: ["code"]
          },
        ]
      }
      price_report_settings: {
        Row: {
          carry_forward_max_adjustments: number
          carry_forward_max_days: number
          id: boolean
          proximity_radius_metres: number
          station_fuel_reports_per_hour: number
        }
        Insert: {
          carry_forward_max_adjustments?: number
          carry_forward_max_days?: number
          id?: boolean
          proximity_radius_metres?: number
          station_fuel_reports_per_hour?: number
        }
        Update: {
          carry_forward_max_adjustments?: number
          carry_forward_max_days?: number
          id?: boolean
          proximity_radius_metres?: number
          station_fuel_reports_per_hour?: number
        }
        Relationships: []
      }
      price_reports: {
        Row: {
          fuel_type_code: string
          id: string
          observed_at: string
          price: number
          proximity_verified: boolean
          recorded_at: string
          station_id: string
        }
        Insert: {
          fuel_type_code: string
          id?: string
          observed_at?: string
          price: number
          proximity_verified?: boolean
          recorded_at?: string
          station_id: string
        }
        Update: {
          fuel_type_code?: string
          id?: string
          observed_at?: string
          price?: number
          proximity_verified?: boolean
          recorded_at?: string
          station_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "price_reports_fuel_type_code_fkey"
            columns: ["fuel_type_code"]
            isOneToOne: false
            referencedRelation: "fuel_types"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "price_reports_station_id_fkey"
            columns: ["station_id"]
            isOneToOne: false
            referencedRelation: "stations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "price_reports_station_id_fkey"
            columns: ["station_id"]
            isOneToOne: false
            referencedRelation: "stations_needing_brand_review"
            referencedColumns: ["id"]
          },
        ]
      }
      stations: {
        Row: {
          address: string | null
          brand_code: string | null
          brand_is_retailer: boolean | null
          created_at: string
          id: string
          latitude: number
          locality_id: string
          longitude: number
          name: string
          provider: string
          provider_fetched_at: string
          provider_place_id: string
        }
        Insert: {
          address?: string | null
          brand_code?: string | null
          brand_is_retailer?: boolean | null
          created_at?: string
          id?: string
          latitude: number
          locality_id: string
          longitude: number
          name: string
          provider?: string
          provider_fetched_at: string
          provider_place_id: string
        }
        Update: {
          address?: string | null
          brand_code?: string | null
          brand_is_retailer?: boolean | null
          created_at?: string
          id?: string
          latitude?: number
          locality_id?: string
          longitude?: number
          name?: string
          provider?: string
          provider_fetched_at?: string
          provider_place_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stations_brand_is_retailer_fkey"
            columns: ["brand_code", "brand_is_retailer"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["code", "is_retailer"]
          },
          {
            foreignKeyName: "stations_locality_id_fkey"
            columns: ["locality_id"]
            isOneToOne: false
            referencedRelation: "localities"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      adjustment_feed_divergence: {
        Row: {
          best_locality: number | null
          fuel_type: string | null
          localities_compared: number | null
          median_divergence: number | null
          new_period_end: string | null
          previous_period_end: string | null
          worst_locality: number | null
        }
        Relationships: []
      }
      adjustment_feed_health: {
        Row: {
          exceeded: boolean | null
          fuel_types_compared: number | null
          fuel_types_voting: number | null
          threshold: number | null
          worst_fuel_median: number | null
          worst_fuel_type: string | null
        }
        Relationships: []
      }
      adjustment_feed_state: {
        Row: {
          adjustments_on_record: number | null
          last_adjustment_effective_at: string | null
          last_outcome:
            | Database["public"]["Enums"]["adjustment_run_outcome"]
            | null
          last_reached_sources_at: string | null
          last_run_at: string | null
        }
        Relationships: []
      }
      brands_needing_product_review: {
        Row: {
          code: string | null
          display_name: string | null
          products: number | null
          products_review_note: string | null
          products_source_url: string | null
          products_verified_at: string | null
          sort_order: number | null
          stations: number | null
          why: string | null
        }
        Relationships: []
      }
      stations_needing_brand_review: {
        Row: {
          address: string | null
          id: string | null
          latitude: number | null
          locality: string | null
          longitude: number | null
          name: string | null
          provider: string | null
          provider_fetched_at: string | null
          provider_place_id: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      check_brand_name_normalization: {
        Args: never
        Returns: {
          actual: string
          case_name: string
          expected: string
          passed: boolean
        }[]
      }
      compare_feed_to_reference: {
        Args: never
        Returns: Database["public"]["CompositeTypes"]["feed_reference_comparison"][]
        SetofOptions: {
          from: "*"
          to: "feed_reference_comparison"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      correct_price_adjustment: {
        Args: {
          p_adjustment_id: string
          p_amount?: number
          p_effective_at?: string
          p_reason: string
        }
        Returns: string
      }
      distance_metres: {
        Args: {
          p_lat_a: number
          p_lat_b: number
          p_lon_a: number
          p_lon_b: number
        }
        Returns: number
      }
      get_doe_reference_prices: {
        Args: { p_fuel_type: string; p_locality: string }
        Returns: Database["public"]["CompositeTypes"]["doe_price_result"][]
        SetofOptions: {
          from: "*"
          to: "doe_price_result"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_station_fuel_options: {
        Args: { p_station_id: string }
        Returns: {
          fuel_type_code: string
          label: string
          label_source: string
          sort_order: number
        }[]
      }
      get_station_prices: {
        Args: { p_fuel_type?: string; p_locality: string }
        Returns: Database["public"]["CompositeTypes"]["station_price_result"][]
        SetofOptions: {
          from: "*"
          to: "station_price_result"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      get_stations_with_reference_prices: {
        Args: { p_fuel_type: string; p_locality: string }
        Returns: Database["public"]["CompositeTypes"]["station_reference_result"][]
        SetofOptions: {
          from: "*"
          to: "station_reference_result"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      is_no_outlet_marker: { Args: { raw: string }; Returns: boolean }
      load_doe_reference_prices: {
        Args: {
          p_period_end: string
          p_period_label: string
          p_period_start: string
          p_region_code: string
          p_rows: Json
          p_source_url: string
        }
        Returns: string
      }
      normalize_brand_name: { Args: { p_name: string }; Returns: string }
      normalize_doe_price: { Args: { raw: string }; Returns: number }
      normalize_locality_label: { Args: { label: string }; Returns: string }
      resolve_station_brand: {
        Args: { p_brand: string; p_name: string; p_operator: string }
        Returns: string
      }
      stations_within_radius: {
        Args: { p_latitude: number; p_longitude: number }
        Returns: {
          address: string
          brand_display: string
          distance_metres: number
          latitude: number
          locality: string
          longitude: number
          provider_place_id: string
          station_id: string
          station_name: string
        }[]
      }
      submit_price_report: {
        Args: {
          p_fuel_type: string
          p_latitude: number
          p_longitude: number
          p_price: number
          p_station_id: string
        }
        Returns: string
      }
    }
    Enums: {
      adjustment_run_outcome:
        | "recorded"
        | "none_announced"
        | "corroboration_missing"
        | "conflict"
        | "failed"
      doe_brand_presence: "reported" | "no_outlet"
      doe_load_run_status: "in_progress" | "succeeded" | "failed"
      doe_locality_report_status: "data" | "no_outlet"
      doe_resolution_strategy: "date_derived" | "discovery"
      locality_sourcing_mode: "direct" | "proxy"
      price_kind: "observed" | "derived" | "reference"
      reference_absence_reason:
        | "no_data_ingested"
        | "locality_not_covered"
        | "fuel_type_not_reported"
        | "brand_not_reported"
        | "brand_not_identified"
    }
    CompositeTypes: {
      doe_price_result: {
        locality: string | null
        doe_source_locality: string | null
        proxy_source: string | null
        fuel_type: string | null
        brand: string | null
        brand_presence: Database["public"]["Enums"]["doe_brand_presence"] | null
        min_price: number | null
        max_price: number | null
        common_price: number | null
        period_start: string | null
        period_end: string | null
        period_label: string | null
        recorded_at: string | null
        source_url: string | null
        has_data: boolean | null
        absence_reason:
          | Database["public"]["Enums"]["reference_absence_reason"]
          | null
      }
      feed_reference_comparison: {
        locality: string | null
        fuel_type: string | null
        previous_period_end: string | null
        new_period_end: string | null
        previous_midpoint: number | null
        new_midpoint: number | null
        doe_movement: number | null
        feed_movement: number | null
        divergence: number | null
      }
      station_price_result: {
        station_id: string | null
        provider_place_id: string | null
        station_name: string | null
        brand_code: string | null
        brand_display: string | null
        address: string | null
        latitude: number | null
        longitude: number | null
        locality: string | null
        fuel_type: string | null
        fuel_display: string | null
        price_kind: Database["public"]["Enums"]["price_kind"] | null
        price_basis: unknown
        absence_reason:
          | Database["public"]["Enums"]["reference_absence_reason"]
          | null
        price: number | null
        report_count: number | null
        newest_report_at: string | null
        baseline_price: number | null
        baseline_observed_at: string | null
        adjustments_applied: number | null
        min_price: number | null
        max_price: number | null
        common_price: number | null
        reference_shifted_by: number | null
        doe_source_locality: string | null
        proxy_source: string | null
        period_start: string | null
        period_end: string | null
        period_label: string | null
        source_url: string | null
        station_attribution: string | null
      }
      station_reference_result: {
        station_id: string | null
        provider_place_id: string | null
        station_name: string | null
        brand_code: string | null
        brand_display: string | null
        address: string | null
        latitude: number | null
        longitude: number | null
        locality: string | null
        has_reference_data: boolean | null
        reference_basis: string | null
        fuel_type: string | null
        doe_source_locality: string | null
        proxy_source: string | null
        min_price: number | null
        max_price: number | null
        common_price: number | null
        period_start: string | null
        period_end: string | null
        period_label: string | null
        source_url: string | null
        station_attribution: string | null
        absence_reason:
          | Database["public"]["Enums"]["reference_absence_reason"]
          | null
      }
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      adjustment_run_outcome: [
        "recorded",
        "none_announced",
        "corroboration_missing",
        "conflict",
        "failed",
      ],
      doe_brand_presence: ["reported", "no_outlet"],
      doe_load_run_status: ["in_progress", "succeeded", "failed"],
      doe_locality_report_status: ["data", "no_outlet"],
      doe_resolution_strategy: ["date_derived", "discovery"],
      locality_sourcing_mode: ["direct", "proxy"],
      price_kind: ["observed", "derived", "reference"],
      reference_absence_reason: [
        "no_data_ingested",
        "locality_not_covered",
        "fuel_type_not_reported",
        "brand_not_reported",
        "brand_not_identified",
      ],
    },
  },
} as const
