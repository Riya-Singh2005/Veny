export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      addresses: {
        Row: {
          area: string
          city: string
          country_code: string
          created_at: string
          id: string
          is_default: boolean
          label: string | null
          line1: string
          line2: string | null
          location: unknown
          location_source: Database["public"]["Enums"]["location_source"]
          postal_code: string | null
          profile_id: string
          state: string
          updated_at: string
        }
        Insert: {
          area: string
          city: string
          country_code?: string
          created_at?: string
          id?: string
          is_default?: boolean
          label?: string | null
          line1: string
          line2?: string | null
          location?: unknown
          location_source: Database["public"]["Enums"]["location_source"]
          postal_code?: string | null
          profile_id?: string
          state: string
          updated_at?: string
        }
        Update: {
          area?: string
          city?: string
          country_code?: string
          created_at?: string
          id?: string
          is_default?: boolean
          label?: string | null
          line1?: string
          line2?: string | null
          location?: unknown
          location_source?: Database["public"]["Enums"]["location_source"]
          postal_code?: string | null
          profile_id?: string
          state?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "addresses_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_audit_log: {
        Row: {
          action: string
          actor_id: string | null
          after: Json | null
          before: Json | null
          created_at: string
          id: number
          note: string | null
          target_id: string
          target_table: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          after?: Json | null
          before?: Json | null
          created_at?: string
          id?: never
          note?: string | null
          target_id: string
          target_table: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          after?: Json | null
          before?: Json | null
          created_at?: string
          id?: never
          note?: string | null
          target_id?: string
          target_table?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_audit_log_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      admin_users: {
        Row: {
          granted_at: string
          granted_by: string | null
          profile_id: string
        }
        Insert: {
          granted_at?: string
          granted_by?: string | null
          profile_id: string
        }
        Update: {
          granted_at?: string
          granted_by?: string | null
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "admin_users_granted_by_fkey"
            columns: ["granted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "admin_users_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      booking_status_history: {
        Row: {
          booking_id: string
          changed_by: string | null
          created_at: string
          from_status: Database["public"]["Enums"]["booking_status"] | null
          id: number
          reason: string | null
          to_status: Database["public"]["Enums"]["booking_status"]
        }
        Insert: {
          booking_id: string
          changed_by?: string | null
          created_at?: string
          from_status?: Database["public"]["Enums"]["booking_status"] | null
          id?: never
          reason?: string | null
          to_status: Database["public"]["Enums"]["booking_status"]
        }
        Update: {
          booking_id?: string
          changed_by?: string | null
          created_at?: string
          from_status?: Database["public"]["Enums"]["booking_status"] | null
          id?: never
          reason?: string | null
          to_status?: Database["public"]["Enums"]["booking_status"]
        }
        Relationships: [
          {
            foreignKeyName: "booking_status_history_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "booking_status_history_changed_by_fkey"
            columns: ["changed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      bookings: {
        Row: {
          address_location: unknown
          address_snapshot: Json
          cancel_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          completed_at: string | null
          confirmed_at: string | null
          created_at: string
          currency: string
          customer_id: string
          customer_notes: string | null
          id: string
          price_paise: number
          reference: string
          scheduled_at: string
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          updated_at: string
          vendor_id: string
        }
        Insert: {
          address_location?: unknown
          address_snapshot: Json
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          completed_at?: string | null
          confirmed_at?: string | null
          created_at?: string
          currency: string
          customer_id: string
          customer_notes?: string | null
          id?: string
          price_paise: number
          reference: string
          scheduled_at: string
          service_id: string
          started_at?: string | null
          status?: Database["public"]["Enums"]["booking_status"]
          updated_at?: string
          vendor_id: string
        }
        Update: {
          address_location?: unknown
          address_snapshot?: Json
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          completed_at?: string | null
          confirmed_at?: string | null
          created_at?: string
          currency?: string
          customer_id?: string
          customer_notes?: string | null
          id?: string
          price_paise?: number
          reference?: string
          scheduled_at?: string
          service_id?: string
          started_at?: string | null
          status?: Database["public"]["Enums"]["booking_status"]
          updated_at?: string
          vendor_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "bookings_cancelled_by_fkey"
            columns: ["cancelled_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["profile_id"]
          },
        ]
      }
      categories: {
        Row: {
          icon: string | null
          id: number
          is_active: boolean
          name: string
          slug: string
          sort_order: number
        }
        Insert: {
          icon?: string | null
          id?: never
          is_active?: boolean
          name: string
          slug: string
          sort_order?: number
        }
        Update: {
          icon?: string | null
          id?: never
          is_active?: boolean
          name?: string
          slug?: string
          sort_order?: number
        }
        Relationships: []
      }
      notifications: {
        Row: {
          body: string
          booking_id: string | null
          created_at: string
          emailed_at: string | null
          id: string
          link: string | null
          read_at: string | null
          title: string
          type: Database["public"]["Enums"]["notification_type"]
          user_id: string
        }
        Insert: {
          body: string
          booking_id?: string | null
          created_at?: string
          emailed_at?: string | null
          id?: string
          link?: string | null
          read_at?: string | null
          title: string
          type: Database["public"]["Enums"]["notification_type"]
          user_id: string
        }
        Update: {
          body?: string
          booking_id?: string | null
          created_at?: string
          emailed_at?: string | null
          id?: string
          link?: string | null
          read_at?: string | null
          title?: string
          type?: Database["public"]["Enums"]["notification_type"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notifications_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_path: string | null
          created_at: string
          full_name: string
          id: string
          phone_e164: string | null
          role: Database["public"]["Enums"]["user_role"]
          updated_at: string
        }
        Insert: {
          avatar_path?: string | null
          created_at?: string
          full_name: string
          id: string
          phone_e164?: string | null
          role?: Database["public"]["Enums"]["user_role"]
          updated_at?: string
        }
        Update: {
          avatar_path?: string | null
          created_at?: string
          full_name?: string
          id?: string
          phone_e164?: string | null
          role?: Database["public"]["Enums"]["user_role"]
          updated_at?: string
        }
        Relationships: []
      }
      reviews: {
        Row: {
          author_name: string
          booking_id: string
          comment: string | null
          created_at: string
          customer_id: string
          id: string
          is_hidden: boolean
          rating: number
          service_id: string
          updated_at: string
          vendor_reply: string | null
        }
        Insert: {
          author_name: string
          booking_id: string
          comment?: string | null
          created_at?: string
          customer_id: string
          id?: string
          is_hidden?: boolean
          rating: number
          service_id: string
          updated_at?: string
          vendor_reply?: string | null
        }
        Update: {
          author_name?: string
          booking_id?: string
          comment?: string | null
          created_at?: string
          customer_id?: string
          id?: string
          is_hidden?: boolean
          rating?: number
          service_id?: string
          updated_at?: string
          vendor_reply?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "reviews_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: true
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "reviews_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["id"]
          },
        ]
      }
      service_images: {
        Row: {
          alt_text: string | null
          created_at: string
          id: string
          position: number
          service_id: string
          storage_path: string
        }
        Insert: {
          alt_text?: string | null
          created_at?: string
          id?: string
          position: number
          service_id: string
          storage_path: string
        }
        Update: {
          alt_text?: string | null
          created_at?: string
          id?: string
          position?: number
          service_id?: string
          storage_path?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_images_service_id_fkey"
            columns: ["service_id"]
            isOneToOne: false
            referencedRelation: "services"
            referencedColumns: ["id"]
          },
        ]
      }
      services: {
        Row: {
          avg_rating: number
          category_id: number
          created_at: string
          currency: string
          deleted_at: string | null
          description: string
          duration_minutes: number | null
          hidden_at: string | null
          id: string
          is_active: boolean
          location: unknown
          price_paise: number
          review_count: number
          search_tsv: unknown
          slug: string
          title: string
          updated_at: string
          vendor_id: string
        }
        Insert: {
          avg_rating?: number
          category_id: number
          created_at?: string
          currency?: string
          deleted_at?: string | null
          description: string
          duration_minutes?: number | null
          hidden_at?: string | null
          id?: string
          is_active?: boolean
          location: unknown
          price_paise: number
          review_count?: number
          search_tsv?: unknown
          slug: string
          title: string
          updated_at?: string
          vendor_id: string
        }
        Update: {
          avg_rating?: number
          category_id?: number
          created_at?: string
          currency?: string
          deleted_at?: string | null
          description?: string
          duration_minutes?: number | null
          hidden_at?: string | null
          id?: string
          is_active?: boolean
          location?: unknown
          price_paise?: number
          review_count?: number
          search_tsv?: unknown
          slug?: string
          title?: string
          updated_at?: string
          vendor_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "services_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "services_vendor_id_fkey"
            columns: ["vendor_id"]
            isOneToOne: false
            referencedRelation: "vendors"
            referencedColumns: ["profile_id"]
          },
        ]
      }
      vendors: {
        Row: {
          base_location: unknown
          bio: string | null
          business_name: string
          created_at: string
          logo_path: string | null
          profile_id: string
          service_radius_m: number
          slug: string
          status: Database["public"]["Enums"]["vendor_status"]
          updated_at: string
          verified_at: string | null
          whatsapp_e164: string | null
        }
        Insert: {
          base_location?: unknown
          bio?: string | null
          business_name: string
          created_at?: string
          logo_path?: string | null
          profile_id: string
          service_radius_m?: number
          slug: string
          status?: Database["public"]["Enums"]["vendor_status"]
          updated_at?: string
          verified_at?: string | null
          whatsapp_e164?: string | null
        }
        Update: {
          base_location?: unknown
          bio?: string | null
          business_name?: string
          created_at?: string
          logo_path?: string | null
          profile_id?: string
          service_radius_m?: number
          slug?: string
          status?: Database["public"]["Enums"]["vendor_status"]
          updated_at?: string
          verified_at?: string | null
          whatsapp_e164?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "vendors_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_set_review_hidden: {
        Args: { p_hidden: boolean; p_note?: string; p_review_id: string }
        Returns: undefined
      }
      admin_set_service_hidden: {
        Args: { p_hidden: boolean; p_note?: string; p_service_id: string }
        Returns: undefined
      }
      admin_set_vendor_status: {
        Args: {
          p_note?: string
          p_status: Database["public"]["Enums"]["vendor_status"]
          p_vendor_id: string
        }
        Returns: Database["public"]["Enums"]["vendor_status"]
      }
      create_booking: {
        Args: {
          p_address_id: string
          p_notes?: string
          p_scheduled_at: string
          p_service_id: string
        }
        Returns: {
          address_location: unknown
          address_snapshot: Json
          cancel_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          completed_at: string | null
          confirmed_at: string | null
          created_at: string
          currency: string
          customer_id: string
          customer_notes: string | null
          id: string
          price_paise: number
          reference: string
          scheduled_at: string
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          updated_at: string
          vendor_id: string
        }
        SetofOptions: {
          from: "*"
          to: "bookings"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      create_review: {
        Args: { p_booking_id: string; p_comment?: string; p_rating: number }
        Returns: {
          author_name: string
          booking_id: string
          comment: string | null
          created_at: string
          customer_id: string
          id: string
          is_hidden: boolean
          rating: number
          service_id: string
          updated_at: string
          vendor_reply: string | null
        }
        SetofOptions: {
          from: "*"
          to: "reviews"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      get_booking_contact: {
        Args: { p_booking_id: string }
        Returns: {
          email: string
          name: string
          phone_e164: string
          whatsapp_e164: string
        }[]
      }
      get_my_vendor: {
        Args: never
        Returns: {
          bio: string
          business_name: string
          lat: number
          lng: number
          logo_path: string
          profile_id: string
          service_radius_m: number
          slug: string
          status: Database["public"]["Enums"]["vendor_status"]
          verified_at: string
          whatsapp_e164: string
        }[]
      }
      mark_notifications_read: { Args: { p_ids?: string[] }; Returns: number }
      search_services: {
        Args: {
          p_category?: string
          p_lat?: number
          p_limit?: number
          p_lng?: number
          p_max_paise?: number
          p_min_paise?: number
          p_offset?: number
          p_q?: string
          p_radius_m?: number
          p_sort?: string
        }
        Returns: {
          avg_rating: number
          category_slug: string
          cover_path: string
          currency: string
          distance_m: number
          duration_minutes: number
          id: string
          price_paise: number
          review_count: number
          slug: string
          title: string
          total_count: number
          vendor_name: string
          vendor_slug: string
          vendor_status: Database["public"]["Enums"]["vendor_status"]
        }[]
      }
      soft_delete_service: {
        Args: { p_service_id: string }
        Returns: undefined
      }
      transition_booking: {
        Args: {
          p_booking_id: string
          p_reason?: string
          p_to: Database["public"]["Enums"]["booking_status"]
        }
        Returns: {
          address_location: unknown
          address_snapshot: Json
          cancel_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          completed_at: string | null
          confirmed_at: string | null
          created_at: string
          currency: string
          customer_id: string
          customer_notes: string | null
          id: string
          price_paise: number
          reference: string
          scheduled_at: string
          service_id: string
          started_at: string | null
          status: Database["public"]["Enums"]["booking_status"]
          updated_at: string
          vendor_id: string
        }
        SetofOptions: {
          from: "*"
          to: "bookings"
          isOneToOne: true
          isSetofReturn: false
        }
      }
    }
    Enums: {
      booking_status:
        | "pending"
        | "confirmed"
        | "in_progress"
        | "completed"
        | "cancelled"
      location_source: "gps" | "geocoded" | "manual_unverified"
      notification_type:
        | "booking_new"
        | "booking_confirmed"
        | "booking_cancelled"
        | "booking_in_progress"
        | "booking_completed"
        | "review_new"
      user_role: "customer" | "vendor"
      vendor_status: "unverified" | "pending" | "verified" | "suspended"
    }
    CompositeTypes: {
      [_ in never]: never
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
      booking_status: [
        "pending",
        "confirmed",
        "in_progress",
        "completed",
        "cancelled",
      ],
      location_source: ["gps", "geocoded", "manual_unverified"],
      notification_type: [
        "booking_new",
        "booking_confirmed",
        "booking_cancelled",
        "booking_in_progress",
        "booking_completed",
        "review_new",
      ],
      user_role: ["customer", "vendor"],
      vendor_status: ["unverified", "pending", "verified", "suspended"],
    },
  },
} as const

