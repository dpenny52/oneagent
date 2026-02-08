import { motion } from "framer-motion";
import { C } from "../../lib/theme";

export function StepCard({
  number,
  title,
  description,
  delay,
}: {
  number: string;
  title: string;
  description: string;
  delay: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 30 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.3 }}
      transition={{ duration: 0.7, delay, ease: "easeOut" }}
      style={{
        display: "flex",
        alignItems: "flex-start",
        gap: "1.5rem",
        padding: "2rem 0",
        borderBottom: `1px solid ${C.forestDim}`,
      }}
    >
      <div
        style={{
          fontFamily: "var(--font-instrument), serif",
          fontSize: "2.5rem",
          color: C.glow,
          opacity: 0.5,
          lineHeight: 1,
          minWidth: 60,
          textAlign: "center",
          textShadow: `0 0 20px ${C.glow}33`,
        }}
      >
        {number}
      </div>
      <div>
        <h3
          style={{
            fontFamily: "var(--font-instrument), serif",
            fontSize: "1.25rem",
            fontWeight: 400,
            color: "#fff",
            marginBottom: "0.5rem",
          }}
        >
          {title}
        </h3>
        <p
          style={{
            fontFamily: "var(--font-dm), sans-serif",
            fontSize: "0.95rem",
            lineHeight: 1.7,
            color: C.muted,
            fontWeight: 300,
          }}
        >
          {description}
        </p>
      </div>
    </motion.div>
  );
}
